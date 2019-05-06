local state
local xtouch

local trackvolpan_vol = {[false] = 2, [true] = 5}


function master_track()
  local s = renoise.song()
  for _, t in pairs(s.tracks) do
    if t.type == renoise.Track.TRACK_TYPE_MASTER then
      return t
    end
  end
end


-- local assign_table = {}

function to_xtouch(source, event)
  local t = type(source)
  --oprint(source)
  return event ~= nil and (t == 'DocumentNode' and source.path ~= nil or t == 'string')
end



function fader_to_value(x)
  return math.db2lin(math.fader2db(-96, 3, x))
end

function value_to_fader(x)
  return math.db2fader(-96, 3, math.lin2db(x))
end


function assign_tracks()
  local song = renoise.song()
  if song == nil then
    song = {tracks = {}}
  end
  local skip_master = 0
  for chan_num = 1, 8 do
    local track_num = chan_num + state.track_offset.value + skip_master
    local c = xtouch.channels[chan_num]
--    if track_num < (#song.tracks - song.send_track_count - 1) then
    if track_num < #song.tracks and song.tracks[track_num].type == renoise.Track.TRACK_TYPE_MASTER then
      skip_master = 1
      track_num = track_num + 1
    end
    if track_num < #song.tracks then
      local t = song.tracks[track_num]
      print("CHANNEL", chan_num, 'TRACK', track_num, t.name)
      local vol = t.devices[1].parameters[trackvolpan_vol[state.post.value]]
      local vol_val = vol.value
      assign(c.fader, 'move', function(event, widget)
        vol.value = fader_to_value(c.fader.value.value)
      end)
      assign(vol.value_observable, function()
        c.fader.value.value = value_to_fader(vol.value)
      end)
      vol.value = vol_val
      assign(c.mute, 'press', function()
        t.mute_state = ({3, 2, 1})[t.mute_state]
        c.mute.led.value = t.mute_state > 1 and 1 or 0
      end)
      xtouch:tap(track_num, state.post.value and #song.tracks[track_num].devices + 1 or 1, chan_num)
      c.screen.line1.value = ''
      c.screen.line2.value = string.sub(t.name, 1, 7)
      c.screen.color[1].value = t.color[1]
      c.screen.color[2].value = t.color[2]
      c.screen.color[3].value = t.color[3]
      c.screen.inverse.value = true
    else
      unassign(c.select, 'press')
      unassign(c.mute, 'press')
      unassign(c.solo, 'press')
      unassign(c.rec, 'press')
      xtouch:untap(track_num)
      unassign(c.fader, 'move')
      c.screen.color[1].value = 0
      c.screen.color[2].value = 0
      c.screen.color[3].value = 0
    end
    xtouch:send_strip(chan_num)
  end
end

local led_state = true

function toggle_VU_LEDs()
  if led_state then
    xtouch:cleanup_LED_support()
    led_state = false
  else
    xtouch:init_LED_support()
    led_state = true
  end
end

function toggle_pre_post()
  state.post.value = not state.post.value
  assign_tracks()
end

function init_mixer()
  led_state = true
  assign_tracks()
  assign(xtouch.bank.left, 'press', function()
    if state.track_offset.value < 8 then state.track_offset.value = 0 else state.track_offset.value = state.track_offset.value - 8 end
    print('bank left', state.track_offset.value)
  end)
  assign(xtouch.bank.right, 'press', function()
    if state.track_offset.value > (#renoise.song().tracks - 8) then state.track_offset.value = #renoise.song().tracks - 8 else state.track_offset.value = state.track_offset.value + 8 end
    print('bank right', state.track_offset.value)
  end)
  assign(xtouch.channel.left, 'press', function()
    if state.track_offset.value > 0 then state.track_offset.value = state.track_offset.value - 1 end
    print('channel left', state.track_offset.value)
  end)
  assign(xtouch.channel.right, 'press', function()
    if state.track_offset.value < #renoise.song().tracks then state.track_offset.value = state.track_offset.value + 1 end
    print('channel right', state.track_offset.value)
  end)
  assign(state.track_offset, assign_tracks)
  assign(xtouch.global_view, 'press', toggle_VU_LEDs)
  assign(xtouch.flip, 'press', toggle_pre_post)
end


function render_track_name(cursor, state, screen, t)
  -- print('render track name', t, t.name)
  screen.line1.value = ''
  screen.line2.value = string.sub(t.name, 1, 7)
  screen.color[1].value = t.color[1]
  screen.color[2].value = t.color[2]
  screen.color[3].value = t.color[3]
  screen.inverse.value = true  
end


function pre_post_p(cursor, state)
  if state.post then
    return renoise.song().tracks[cursor.track].postfx_volume
  else
    return renoise.song().tracks[cursor.track].prefx_volume
  end
end


function pre_post_obs(cursor, state)
  return pre_post_p(cursor, state).value_observable
end


function pre_post_value(cursor, state)
  return pre_post_p(cursor, state)
end


mixer_state = renoise.Document.create('mixer_state') {
  post = renoise.app().window.mixer_view_post_fx,
  modifiers = {
    shift = false,
    option = false,
    control = false,
    alt = false,
  },
  current_track = nil,
  current_device = nil,
  current_parameter = nil
}


return function(xtouch)
  local biterator = 1
  local biterator_mask = 0x1fff
  return table.create({
    name = 'Mixer',
    number = 1,
    mode = 'full',  -- 'full' unassigns everything not explicitly assigned here (except for the program selector of course). 'partial' only updates the existing assignments.
    state = mixer_state,
    assign = {
      -- PRE / POST
      { xtouch=xtouch.flip,
        event='press',
        callback=function(cursor, state)
          state.post.value = not state.post.value
          renoise.app().window.mixer_view_post_fx = state.post.value
        end
      },
      { obs=renoise.app().window.mixer_view_post_fx_observable,
        callback=function(cursor, state)
          state.post = renoise.app().window.mixer_view_post_fx
        end
      },
      { obs=mixer_state.post,
        value=mixer_state.post,
        led=xtouch.flip.led,
        to_led=function(cursor, state, v) return v.value and 2 or 0 end
      },
      -- FRANE CONTROL
      { xtouch=xtouch.channel.left,
        event='press',
        cursor_step=-1
      },
      { xtouch=xtouch.channel.right,
        event='press',
        cursor_step=1
      },
      { xtouch=xtouch.bank.left,
        event='press',
        cursor_step=-8
      },
      { xtouch=xtouch.bank.right,
        event='press',
        cursor_step=8
      },
      { xtouch=xtouch.global_view,
        event='press',
        callback=function(cursor, state)
          xtouch.vu_enabled.value = not xtouch.vu_enabled.value
        end        
      },
      -- EMABLE / DISABLE LED HACK
      { obs=xtouch.vu_enabled,
        value=xtouch.vu_enabled,
        led=xtouch.global_view.led,
        to_led=function(cursor, state, v) return v.value and 2 or 0 end
      },
    },
    frame = {
      name = 'track',
      min = function(cursor, state) return 1 end,
      max = function(cursor, state) return #renoise.song().tracks - 1 end,
      values = function(cursor, state)
        local ret, trk = table.create(), renoise.song().tracks
        local M, S = renoise.Track.TRACK_TYPE_MASTER, renoise.Track.TRACK_TYPE_SEND
        for i = 1, #trk do
          if trk[i].type ~= M and (trk[i].type ~= S or string.sub(trk[i].name, 1, 8) ~= 'XT LED #') then
            ret:insert(i)
          end
        end
        return ret
      end,
      channels = {1, 2, 3, 4, 5, 6, 7, 8},
      assign = {
        -- POT
        { xtouch=function(cursor, state) return xtouch.channels[cursor.channel].encoder end,
          event='delta',
          callback=function(cursor, state, event, widget)
            local v
            if state.post then
              v = renoise.song().tracks[cursor.track].postfx_panning.value
              v = v + widget.delta.value *0.01
              if v < 0 then v = 0 end
              if v > 1 then v = 1 end
              renoise.song().tracks[cursor.track].postfx_panning.value = v
            else
              v = renoise.song().tracks[cursor.track].prefx_panning.value
              v = v + widget.delta.value * 0.01
              if v < 0 then v = 0 end
              if v > 1 then v = 1 end
              renoise.song().tracks[cursor.track].prefx_panning.value = v
            end
          end
        },
        { obs=function(cursor, state)
            if state.post then
              return renoise.song().tracks[cursor.track].postfx_panning
            else
              return renoise.song().tracks[cursor.track].prefx_panning
            end
          end,
          value=function(cursor, state)
            if state.post then
              return renoise.song().tracks[cursor.track].postfx_panning.value
            else
              return renoise.song().tracks[cursor.track].prefx_panning.value
            end
          end,
          led=function(cursor, state) return xtouch.channels[cursor.channel].encoder.led end,
          to_led = function(cursor, state, v)
            -- >>> for i = 12, 0, -1 do print('elseif v >', 1.0 * i / 13, 'then return ') end
            if     v >  0.92307692307692  then return 0x003f
            elseif v >  0.84615384615385  then return 0x001f
            elseif v >  0.76923076923077  then return 0x000f
            elseif v >  0.69230769230769  then return 0x0007
            elseif v >  0.61538461538462  then return 0x0003
            elseif v >  0.53846153846154  then return 0x0001
            elseif v >  0.46153846153846  then return 0x1000
            elseif v >  0.38461538461538  then return 0x1800
            elseif v >  0.30769230769231  then return 0x1c00
            elseif v >  0.23076923076923  then return 0x1e00
            elseif v >  0.15384615384615  then return 0x1f00
            elseif v >  0.076923076923077 then return 0x1f80
            elseif v >= 0                 then return 0x1fc0
            end
            return 0
          end
        },
        -- FADER
        { fader=function(cursor, state) return xtouch.channels[cursor.channel].fader end,
          obs=pre_post_obs,
          value=pre_post_value
        },
        -- SELECT
        { led=function(cursor, state) return xtouch.channels[cursor.channel].select.led end,
          obs=function(cursor, state) return renoise.song().selected_track_index_observable end,
          value=function(cursor, state) return renoise.song().selected_track_index end,
          to_led=function(cursor, state, value) return (value == cursor.track) and 2 or 0 end
        },
        { xtouch=function(cursor, state) return xtouch.channels[cursor.channel].select end,
          event='press',
          callback=function(cursor, state) renoise.song().selected_track_index = cursor.track end
        },
        -- VU LEDS
        { vu=function(cursor, state) return cursor.channel end,
          track=function(cursor, state) return cursor.track end,
          at=function(cursor, state) return state.post and #renoise.song().tracks[cursor.track].devices + 1 or 1 end,
          post=function(cursor, state) return state.post end
        },
        -- SCREEN
        { screen = function(cursor, state) return xtouch.channels[cursor.channel].screen end,
          trigger = function(cursor, state) return renoise.song().tracks[cursor.track].name_observable end,
          value = function(cursor, state)
            return renoise.song().tracks[cursor.track]
          end,
          render = render_track_name
        },
        -- MUTE
        { xtouch=function(cursor, state) return xtouch.channels[cursor.channel].mute end,
          event='press',
          callback=function(cursor, state) renoise.song().tracks[cursor.track].mute_state = 4 - renoise.song().tracks[cursor.track].mute_state end,
        },
        { obs=function(cursor, state) return renoise.song().tracks[cursor.track].mute_state_observable end,
          value=function(cursor, state)
            -- rprint(cursor)
            -- oprint(renoise.song().tracks[cursor.track])
            return renoise.song().tracks[cursor.track].mute_state
          end,
          led=function(cursor, state) return xtouch.channels[cursor.channel].mute.led end,
          to_led=function(cursor, state, v) return v == 3 and 2 or 0 end
        },
        -- SOLO
        { xtouch=function(cursor, state) return xtouch.channels[cursor.channel].solo end,
          event='press',
          callback=function(cursor, state) renoise.song().tracks[cursor.track].solo_state = not renoise.song().tracks[cursor.track].solo_state end,
        },
        { obs=function(cursor, state) return renoise.song().tracks[cursor.track].solo_state_observable end,
          value=function(cursor, state) return renoise.song().tracks[cursor.track].solo_state end,
          led=function(cursor, state) return xtouch.channels[cursor.channel].solo.led end,
          to_led=function(cursor, state, v) return v and 2 or 0 end
        }
      },
      refresh_on = function(cursor, state) return renoise.song().tracks_observable end
    }
  })
end


-- return {
--   name = 'Mixer',
--   number = 1,
--   install = function(x)
--     xtouch = x
--     clear_assigns()
--     state = renoise.Document.create('mixer_state') {
--       page_number = 1,
--       track_offset = 0,
--       post = true
--     }
--     init_mixer()
--   end,
--   uninstall = function(x)
--   end
-- }
