local state
local xtouch

local trackvolpan_vol = {[false] = 2, [true] = 5}


function to_xtouch(source, event)
  local t = type(source)
  --oprint(source)
  return event ~= nil and (t == 'DocumentNode' and source.path ~= nil or t == 'string')
end


function master_track()
  local tracks = renoise.song().tracks
  for i =  #tracks, 1, -1 do
    if tracks[i].type == renoise.Track.TRACK_TYPE_MASTER then return i end
  end
end


function fader_to_value(x)
  return math.db2lin(math.fader2db(-96, 3, x))
end

function value_to_fader(x)
  return math.db2fader(-96, 3, math.lin2db(x))
end


function toggle_pre_post()
  state.post.value = not state.post.value
  assign_tracks()
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
  if state.post.value then
    -- return renoise.song().tracks[cursor.track].postfx_volume
    return renoise.song().tracks[cursor.track].devices[1].parameters[5]
  else
    -- return renoise.song().tracks[cursor.track].prefx_volume
    return renoise.song().tracks[cursor.track].devices[1].parameters[2]
  end
end


function pre_post_obs(cursor, state)
  print('pre_post_obs', cursor.track)
  return pre_post_p(cursor, state).value_observable
end


function pre_post_value(cursor, state)
  print('pre_post_value', cursor.track)
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


function transport_ofs(seq_ofs, beat_ofs)
  local len = renoise.song().transport.song_length
  local pos
  if renoise.song().transport.playing then
    pos = renoise.song().transport.playback_pos
  else
    pos = renoise.song().transport.edit_pos
  end
  pos.sequence = pos.sequence + seq_ofs
  if pos.sequence < 1 then pos.sequence = 1 end
  if pos.sequence > len.sequence then pos.sequence = len.sequence end
  if renoise.song().transport.playing then
    renoise.song().transport.playback_pos = pos
  else
    renoise.song().transport.edit_pos = pos
  end
end




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
      { xtouch=xtouch.flip, event='press', frame='update',
        callback=function(cursor, state)
          state.post.value = not state.post.value
          renoise.app().window.mixer_view_post_fx = state.post.value
          xtouch.flip.led.value = state.post.value and 2 or 0
        end,
      },
      { renoise=renoise.app().window.mixer_view_post_fx_observable, frame='update',
        callback=function(cursor, state)
          state.post.value = renoise.app().window.mixer_view_post_fx
          xtouch.flip.led.value = state.post.value and 2 or 0
        end,
      },
      -- MAIN FADER
      { fader=xtouch.channels.main.fader,
        obs=function(cursor, state) return pre_post_obs({track=master_track()}, state) end,
        value=function(cursor, state) return pre_post_value({track=master_track()}, state) end,
      },
      -- WRAPPED PATTERN EDIT MODE TOGGLE
      { xtouch=xtouch.scrub, event='press', callback=function(cursor, state) renoise.song().transport.wrapped_pattern_edit = not renoise.song().transport.wrapped_pattern_edit end },
      { obs=function(cursor, state) return renoise.song().transport.wrapped_pattern_edit_observable end,
        value=function(cursor, state) return renoise.song().transport.wrapped_pattern_edit end,
        led=xtouch.scrub.led
      },
      -- TRANSPORT
      { xtouch=xtouch.transport.forward, event='press', callback=function() transport_ofs(1) xtouch.transport.forward.led.value = 2 end },
      { xtouch=xtouch.transport.rewind, event='press', callback=function() transport_ofs(-1) xtouch.transport.rewind.led.value = 2 end },
      { xtouch=xtouch.transport.forward, event='release', callback=function() transport_ofs(1) xtouch.transport.forward.led.value = 0 end },
      { xtouch=xtouch.transport.rewind, event='release', callback=function() transport_ofs(-1) xtouch.transport.rewind.led.value = 0 end },
      { xtouch=xtouch.transport.stop, event='press', callback=function() renoise.song().transport.playing = false end },
      { xtouch=xtouch.transport.play, event='press', callback=function() renoise.song().transport.playing = true end },
      { renoise=function() return renoise.song().transport.playing_observable end,
        callback=function()
          if renoise.song().transport.playing then
            xtouch.transport.stop.led.value = 0
            xtouch.transport.play.led.value = 2
          else
            xtouch.transport.stop.led.value = 2
            xtouch.transport.play.led.value = 0
          end
        end
      },
      { xtouch=xtouch.transport.record, event='press', callback=function() renoise.song().transport.edit_mode = not renoise.song().transport.edit_mode end },
      { renoise=function() return renoise.song().transport.edit_mode_observable end, callback=function() xtouch.transport.record.led.value = renoise.song().transport.edit_mode and 2 or 0 end },
      { xtouch=xtouch.transport.jog_wheel, event='delta',
        callback=function()
          local len = renoise.song().transport.song_length_beats
          local cur
          if renoise.song().transport.playing then
            cur = renoise.song().transport.playback_pos_beats
          else
            cur = renoise.song().transport.edit_pos_beats
          end
          cur = cur + xtouch.transport.jog_wheel.delta.value
          if cur < 0 then cur = 0 end
          if cur >= len then cur = len - 1 end
          if renoise.song().transport.playing then
            renoise.song().transport.playback_pos_beats = cur
          else
            renoise.song().transport.edit_pos_beats = cur
          end
        end
      },
  -- FRANE CONTROL
      { xtouch=xtouch.channel.left, event='press',
        cursor_step=-1
      },
      { xtouch=xtouch.channel.right, event='press',
        cursor_step=1
      },
      { xtouch=xtouch.bank.left, event='press',
        cursor_step=-8
      },
      { xtouch=xtouch.bank.right, event='press',
        cursor_step=8
      },
      { xtouch=xtouch.global_view, event='press',
        callback=function(cursor, state) xtouch.vu_enabled.value = not xtouch.vu_enabled.value end
      },
      -- EMABLE / DISABLE LED HACK
      { obs=xtouch.vu_enabled, value=xtouch.vu_enabled, led=xtouch.global_view.led,
        to_led=function(cursor, state, v) return v.value and 2 or 0 end
      },
      -- RECALL VIEW PRESETS
      { xtouch=xtouch.midi_tracks, event='press', callback=function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR end },
      { xtouch=xtouch.inputs, event='press', callback=function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER end },
      { xtouch=xtouch.audio_tracks, event='press', callback=function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR end },
      { xtouch=xtouch.audio_inst, event='press', callback=function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES end },
      { xtouch=xtouch.aux, event='press', callback=function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR end },
      { xtouch=xtouch.buses, event='press', callback=function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION end },
      { xtouch=xtouch.outputs, event='press', callback=function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS end },
      { xtouch=xtouch.user, event='press', callback=function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR end },
      { renoise=renoise.app().window.active_middle_frame_observable, callback=function(cursor, state)
          local f = renoise.app().window.active_middle_frame
          print('active_middle_frame', f)
          xtouch.midi_tracks.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR and 2 or 0
          xtouch.inputs.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_MIXER and 2 or 0
          xtouch.audio_tracks.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR and 2 or 0
          xtouch.audio_inst.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES and 2 or 0
          xtouch.aux.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR and 2 or 0
          xtouch.buses.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION and 2 or 0
          xtouch.outputs.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS and 2 or 0
          xtouch.user.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR and 2 or 0
        end
      },
      -- MODIFIERS
      { xtouch=xtouch.modify.shift, event='press', callback=function(c, state) state.modifiers.shift.value = true end },
      { xtouch=xtouch.modify.shift, event='release', callback=function(c, state) state.modifiers.shift.value = false end },
      { led=xtouch.modify.shift.led, obs=function(c, s) return s.modifiers.shift end, value=function(c, s) return s.modifiers.shift.value end },
      { xtouch=xtouch.modify.option, event='press', callback=function(c, state) state.modifiers.option.value = true end },
      { xtouch=xtouch.modify.option, event='release', callback=function(c, state) state.modifiers.option.value = false end },
      { led=xtouch.modify.option.led, obs=function(c, s) return s.modifiers.option end, value=function(c, s) return s.modifiers.option.value end },
      { xtouch=xtouch.modify.alt, event='press', callback=function(c, state) state.modifiers.alt.value = true end },
      { xtouch=xtouch.modify.alt, event='release', callback=function(c, state) state.modifiers.alt.value = false end },
      { led=xtouch.modify.alt.led, obs=function(c, s) return s.modifiers.alt end, value=function(c, s) return s.modifiers.alt.value end },
      { xtouch=xtouch.modify.control, event='press', callback=function(c, state) state.modifiers.control.value = true end },
      { xtouch=xtouch.modify.control, event='release', callback=function(c, state) state.modifiers.control.value = false end },
      { led=xtouch.modify.control.led, obs=function(c, s) return s.modifiers.control end, value=function(c, s) return s.modifiers.control.value end }  
    },
    -- FRAME
    frame = {
      name = 'track',
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
            if state.post.value then
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
            if state.post.value then
              return renoise.song().tracks[cursor.track].postfx_panning
            else
              return renoise.song().tracks[cursor.track].prefx_panning
            end
          end,
          value=function(cursor, state)
            if state.post.value then
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
          at=function(cursor, state) return state.post.value and #renoise.song().tracks[cursor.track].devices + 1 or 2 end,
          post=function(cursor, state) return state.post.value end
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
