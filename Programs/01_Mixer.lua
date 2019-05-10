--
-- Mixer mapping for the X-Touch
-- author: Damien Leroux
--


--================================================================================================
---  SECTION I
--================================================================================================
---  Utility functions
--================================================================================================


local led_center_strip = function(cursor, state, v)
  -- >>> for i = 12, 0, -1 do print('elseif v >', 1.0 * i / 13, 'then return ') end
  if     v >  0.9230 then return 0x003f
  elseif v >  0.8461 then return 0x001f
  elseif v >  0.7692 then return 0x000f
  elseif v >  0.6923 then return 0x0007
  elseif v >  0.6153 then return 0x0003
  elseif v >  0.5384 then return 0x0001
  elseif v >  0.4615 then return 0x1000
  elseif v >  0.3846 then return 0x1800
  elseif v >  0.3076 then return 0x1c00
  elseif v >  0.2307 then return 0x1e00
  elseif v >  0.1538 then return 0x1f00
  elseif v >  0.0769 then return 0x1f80
  elseif v >= 0      then return 0x1fc0
  end
  return 0
end


local led_full_strip_lr = function(cursor, state, v)
  -- >>> for i = 12, 0, -1 do print('elseif v >', 1.0 * i / 13, 'then return ') end
  if     v >  0.9230 then return 0x1fff
  elseif v >  0.8461 then return 0x1fdf
  elseif v >  0.7692 then return 0x1fcf
  elseif v >  0.6923 then return 0x1fc7
  elseif v >  0.6153 then return 0x1fc3
  elseif v >  0.5384 then return 0x1fc1
  elseif v >  0.4615 then return 0x1fc0
  elseif v >  0.3846 then return 0x0fc0
  elseif v >  0.3076 then return 0x07c0
  elseif v >  0.2307 then return 0x03c0
  elseif v >  0.1538 then return 0x01c0
  elseif v >  0.0769 then return 0x00c0
  elseif v >= 0      then return 0x0040
  end
  return 0
end


local led_full_strip_rl = function(cursor, state, v)
  -- >>> for i = 12, 0, -1 do print('elseif v >', 1.0 * i / 13, 'then return ') end
  if     v >  0.9230 then return 0x0020
  elseif v >  0.8461 then return 0x0030
  elseif v >  0.7692 then return 0x0038
  elseif v >  0.6923 then return 0x003c
  elseif v >  0.6153 then return 0x003e
  elseif v >  0.5384 then return 0x003f
  elseif v >  0.4615 then return 0x103f
  elseif v >  0.3846 then return 0x183f
  elseif v >  0.3076 then return 0x1c3f
  elseif v >  0.2307 then return 0x1e3f
  elseif v >  0.1538 then return 0x1f3f
  elseif v >  0.0769 then return 0x1fbf
  elseif v >= 0      then return 0x1fff
  end
  return 0
end


-- https://stackoverflow.com/a/15278426
local TableConcat = function(t1, t2)
  for i = 1, #t2 do
      t1[#t1 + 1] = t2[i]
  end
  return t1
end


local plug_schema = function(target, plugin)
  if plugin.state then
    target.state:add_properties(plugin.state)
  end
  if plugin.assign then
    target.assign = TableConcat(target.assign, plugin.assign)
  end
  if plugin.frame and target.frame then
    target.frame.assign = TableConcat(target.frame.assign, plugin.frame.assign)
  end
end





local to_xtouch = function(source, event)
  local t = type(source)
  --oprint(source)
  return event ~= nil and (t == 'DocumentNode' and source.path ~= nil or t == 'string')
end


local master_track = function()
  local tracks = renoise.song().tracks
  for i =  #tracks, 1, -1 do
    if tracks[i].type == renoise.Track.TRACK_TYPE_MASTER then return i end
  end
end


local strip_vowels = function(str)
  if str:len() <= 7 then return str end
  local initial = str:sub(1, 1)
  local rest = str:sub(2)
  return string.sub(initial .. string.gsub(rest, '[aeiouyAEIOUY ]', ''), 1, 7)
end


local render_track_name = function(cursor, state, screen, t)
  -- print('render track name', t, t.name)
  screen.line1.value = ''
  screen.line2.value = strip_vowels(t.name)
  screen.color[1].value = t.color[1]
  screen.color[2].value = t.color[2]
  screen.color[3].value = t.color[3]
  screen.inverse.value = true
end


local render_device_and_parameter_name = function(cursor, state, screen, t)
  -- print('render track name', t, t.name)
  local d = t.devices[cursor.device]
  local p = d and d.parameters[state.current_param[cursor.channel].value] or nil
  screen.line1.value = strip_vowels(d and d.name or '---')
  screen.line2.value = strip_vowels(p and p.name or '---')
  screen.color[1].value = t.color[1]
  screen.color[2].value = t.color[2]
  screen.color[3].value = t.color[3]
  screen.inverse.value = true
end


local pre_post_p = function(cursor, state)
  if renoise.app().window.mixer_view_post_fx then
    -- return renoise.song().tracks[cursor.track].postfx_volume
    return renoise.song().tracks[cursor.track].devices[1].parameters[5]
  else
    -- return renoise.song().tracks[cursor.track].prefx_volume
    return renoise.song().tracks[cursor.track].devices[1].parameters[2]
  end
end


local pre_post_obs = function(cursor, state)
  if renoise.app().window.mixer_view_post_fx then
    return 'renoise.song().tracks[' .. cursor.track .. '].devices[1].parameters[5]'
  else
    return 'renoise.song().tracks[' .. cursor.track .. '].devices[1].parameters[2]'
  end
end


local pre_post_value = function(cursor, state)
  return pre_post_p(cursor, state)
end



local transport_ofs = function(seq_ofs, beat_ofs)
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


--================================================================================================
---  SECTION II
--================================================================================================
---  Schema plug-ins
--================================================================================================



local modifier_support = function(xtouch, state)
  return table.create({
    assign = {
      { xtouch = 'xtouch.modify.shift,press', callback = function(c, state) state.modifiers.shift.value = true end },
      { xtouch = 'xtouch.modify.shift,release', callback = function(c, state) state.modifiers.shift.value = false end },
      { led = xtouch.modify.shift.led, obs = 'state.modifiers.shift', value = function(c, s) return s.modifiers.shift.value end },
      
      { xtouch = 'xtouch.modify.option,press', callback = function(c, state) state.modifiers.option.value = true end },
      { xtouch = 'xtouch.modify.option,release', callback = function(c, state) state.modifiers.option.value = false end },
      { led = xtouch.modify.option.led, obs = 'state.modifiers.option', value = function(c, s) return s.modifiers.option.value end },
      
      { xtouch = 'xtouch.modify.alt,press', callback = function(c, state) state.modifiers.alt.value = true end },
      { xtouch = 'xtouch.modify.alt,release', callback = function(c, state) state.modifiers.alt.value = false end },
      { led = xtouch.modify.alt.led, obs = 'state.modifiers.alt', value = function(c, s) return s.modifiers.alt.value end },
      
      { xtouch = 'xtouch.modify.control,press', callback = function(c, state) state.modifiers.control.value = true end },
      { xtouch = 'xtouch.modify.control,release', callback = function(c, state) state.modifiers.control.value = false end },
      { led = xtouch.modify.control.led, obs = 'state.modifiers.control', value = function(c, s) return s.modifiers.control.value end }
    },
  })
end

local transport = function(xtouch, state)
  local last_jog_wheel_timestamp = nil
  return table.create({
    assign = {
      { xtouch = 'xtouch.transport.forward,press',   callback = function() transport_ofs(1) xtouch.transport.forward.led.value = 2 end },
      { xtouch = 'xtouch.transport.rewind,press',   callback = function() transport_ofs(-1) xtouch.transport.rewind.led.value = 2 end },
      { xtouch = 'xtouch.transport.forward,release', callback = function() xtouch.transport.forward.led.value = 0 end },
      { xtouch = 'xtouch.transport.rewind,release', callback = function() xtouch.transport.rewind.led.value = 0 end },
      { xtouch = 'xtouch.transport.stop,press',   callback = function() renoise.song().transport.playing = false end },
      { xtouch = 'xtouch.transport.play,press',   callback = function() renoise.song().transport.playing = true end },
      { xtouch = 'xtouch.transport.record,press',   callback = function() renoise.song().transport.edit_mode = not renoise.song().transport.edit_mode end },
      
      { xtouch = 'xtouch.left,press', callback = function() renoise.song().transport.edit_mode = not renoise.song().transport.edit_mode end },
      { xtouch = 'xtouch.right,press', callback = function() renoise.song().transport.edit_mode = not renoise.song().transport.edit_mode end },

      { renoise = 'renoise.song().transport.edit_mode_observable', callback = function() xtouch.transport.record.led.value = renoise.song().transport.edit_mode and 2 or 0 end },
      { renoise = 'renoise.song().transport.playing_observable',
        callback = function()
          if renoise.song().transport.playing then
            xtouch.transport.stop.led.value = 0
            xtouch.transport.play.led.value = 2
          else
            xtouch.transport.stop.led.value = 2
            xtouch.transport.play.led.value = 0
          end
        end
      },
      { xtouch = 'xtouch.transport.jog_wheel,delta',
        callback = function()
          local timestamp = os.clock()
          local multiplier = 1.0 / renoise.song().transport.lpb
          if last_jog_wheel_timestamp then
            local delta_t = timestamp - last_jog_wheel_timestamp
            if delta_t < 0.005 then
              multiplier = 8
            elseif delta_t < 0.010 then
              multiplier = 4
            elseif delta_t < 0.025 then
              multiplier = 2
            elseif delta_t < 0.05 then
              multiplier = 1
            end
            -- print("jog wheel multiplier", xtouch.transport.jog_wheel.delta.value, last_jog_wheel_timestamp, timestamp, multiplier)
          end
          last_jog_wheel_timestamp = timestamp
          local len = renoise.song().transport.song_length_beats
          local cur
          if renoise.song().transport.playing then
            cur = renoise.song().transport.playback_pos_beats
          else
            cur = renoise.song().transport.edit_pos_beats
          end
          cur = cur + (xtouch.transport.jog_wheel.delta.value * multiplier)
          if cur < 0 then cur = 0 end
          if cur >= len then cur = len - (1.0 / renoise.song().transport.lpb) end
          if renoise.song().transport.playing then
            renoise.song().transport.playback_pos_beats = cur
          else
            renoise.song().transport.edit_pos_beats = cur
          end
        end
      },
    }
  })
end


local pot_and_leds_panning = function(xtouch, state)
  return table.create({
    frame = {
      assign = {
        { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].encoder,delta' end,
          callback = function(cursor, state, event, widget)
            local v
            if renoise.app().window.mixer_view_post_fx then
              v = renoise.song().tracks[cursor.track].postfx_panning.value
              v = v + widget.delta.value * 0.01
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
        { obs = function(cursor, state)
            if renoise.app().window.mixer_view_post_fx then
              return 'renoise.song().tracks[' .. cursor.track .. '].postfx_panning'
            else
              return 'renoise.song().tracks[' .. cursor.track .. '].prefx_panning'
            end
          end,
          value = function(cursor, state)
            if renoise.app().window.mixer_view_post_fx then
              return renoise.song().tracks[cursor.track].postfx_panning.value
            else
              return renoise.song().tracks[cursor.track].prefx_panning.value
            end
          end,
          led = function(cursor, state) return xtouch.channels[cursor.channel].encoder.led end,
          to_led = led_center_strip
        },
      }
    }
  })
end


local find_device_parameter = function(track, device, param)
  local t = renoise.song().tracks[track]
  if t == nil then return end
  local d = t.devices[device]
  if d == nil then return end
  return d.parameters[param]
end


--================================================================================================
---  SECTION III
--================================================================================================
---  Schema definitions
--================================================================================================


local device_frame = function(xtouch, s)
  return table.create({
    frame = {
      name = 'device',
      values = function(cursor, state)
        local ret = table.create {}
        print('current track', renoise.song().selected_track_index)
        for i = 2, #renoise.song().tracks[renoise.song().selected_track_index].devices do ret:insert(i) end
        return ret
      end,
      channels = {1, 2, 3, 4, 5, 6, 7, 8},
      assign = {
        { fader = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].fader' end,
          obs = function(cursor, state)
            return ('renoise.song().tracks[' .. renoise.song().selected_track_index ..
                    '].devices[' .. cursor.device .. '].parameters[' .. state.current_param[cursor.channel].value ..
                    '].value_observable')
          end,
          value = function(cursor, state)
            local p = find_device_parameter(renoise.song().selected_track_index, cursor.device, state.current_param[cursor.channel].value)
            if p ~= nil then return p end
          end,
          to_fader = function(cursor, state, value)
            local p = find_device_parameter(renoise.song().selected_track_index, cursor.device, state.current_param[cursor.channel].value)
            if p == nil then return end
            local min = p.value_min
            local max = p.value_max
            local ret = (value - min) / (max - min)
            if ret < min then ret = min end
            if ret > max then ret = max end
            return ret
          end,
          from_fader = function(cursor, state, value)
            local p = find_device_parameter(renoise.song().selected_track_index, cursor.device, state.current_param[cursor.channel].value)
            if p == nil then return end
            local min = p.value_min
            local max = p.value_max
            local ret = min + value * (max - min)
            if ret < min then ret = min end
            if ret > max then ret = max end
            return ret
          end
        },
        -- SCREEN
        { screen = function(cursor, state) return xtouch.channels[cursor.channel].screen end, render = render_device_and_parameter_name,
          trigger = function(cursor, state) return 'renoise.song().tracks[' .. renoise.song().selected_track_index .. '].devices_observable' end,
          value = function(cursor, state) return renoise.song().selected_track end,
        },
        { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].encoder,delta' end,
          frame = 'update',
          callback = function(cursor, state)
            rprint(cursor)
            print(renoise.song().selected_track_index)
            local t = renoise.song().tracks[renoise.song().selected_track_index]
            print(#t.devices, cursor.device)
            if cursor.device > #t.devices then
              return
            end
            local d = t.devices[cursor.device]
            local i = state.current_param[cursor.channel].value
            i = i + xtouch.channels[cursor.channel].encoder.delta
            if i < 1 then i = 1 end
            if i > #d.parameters then i = #d.parameters end
            state.current_param[cursor.channel].value = i
          end
        }
      }
    }
  })
end

local base = function(xtouch, state)
  local schema = table.create {
    assign = {
      -- PRE / POST
      { xtouch = 'xtouch.flip,press',
        callback = function(cursor, state)
          renoise.app().window.mixer_view_post_fx = not renoise.app().window.mixer_view_post_fx
          xtouch.flip.led.value = renoise.app().window.mixer_view_post_fx and 2 or 0
        end,
      },
      { renoise = 'renoise.app().window.mixer_view_post_fx_observable', frame = 'update', callback = function(cursor, state) print('PRE/POST REFRESH') end }, --xtouch.flip.led.value = renoise.app().window.mixer_view_post_fx and 2 or 0 end },
      -- EMABLE / DISABLE LED HACK
      { obs = '(xtouch.vu_enabled)', value = xtouch.vu_enabled, led = xtouch.global_view.led, to_led = function(cursor, state, v) return v.value and 2 or 0 end },
      { xtouch = 'xtouch.global_view,press', frame = 'update', callback = function(cursor, state) xtouch.vu_enabled.value = not xtouch.vu_enabled.value end },
      -- MAIN FADER
      { fader = 'xtouch.channels.main.fader',
        obs = function(cursor, state) return pre_post_obs({track = master_track()}, state) end,
        value = function(cursor, state) return pre_post_value({track = master_track()}, state) end,
      },
      -- WRAPPED PATTERN EDIT MODE TOGGLE
      { xtouch = 'xtouch.scrub,press', callback = function(cursor, state) renoise.song().transport.wrapped_pattern_edit = not renoise.song().transport.wrapped_pattern_edit end },
      { obs = function(cursor, state) return 'renoise.song().transport.wrapped_pattern_edit_observable' end,
        value = function(cursor, state) return renoise.song().transport.wrapped_pattern_edit end,
        led = xtouch.scrub.led
      },
      -- RECALL VIEW PRESETS
      { xtouch = 'xtouch.midi_tracks,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR end },
      { xtouch = 'xtouch.inputs,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER end },
      { xtouch = 'xtouch.audio_tracks,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR end },
      { xtouch = 'xtouch.audio_inst,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES end },
      { xtouch = 'xtouch.aux,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR end },
      { xtouch = 'xtouch.buses,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION end },
      { xtouch = 'xtouch.outputs,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS end },
      { xtouch = 'xtouch.user,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR end },
      { renoise = 'renoise.app().window.active_middle_frame_observable', callback = function(cursor, state)
          local f = renoise.app().window.active_middle_frame
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
      -- ENTER FRAMES
      { xtouch = 'xtouch.encoder_assign.plugin,press', schema = 'device_frame' },
      { xtouch = 'xtouch.encoder_assign.pan,press', schema = 'mixer_frame' },
      { renoise = 'state.current_schema', callback = function(cursor, state)
          xtouch.encoder_assign.pan.led.value = state.current_schema.value == 'mixer_frame' and 2 or 0
          xtouch.encoder_assign.plugin.led.value = state.current_schema.value == 'device_frame' and 2 or state.current_schema.value == 'param_frame' and 1 or 0
        end
      },

      -- REFRESH CONDITIONS
      { renoise = 'renoise.song().tracks_observable', frame = 'update', callback = function() end }
    }
  }

  plug_schema(schema, modifier_support(xtouch))
  plug_schema(schema, transport(xtouch))

  return schema
end

local last_playpos = nil

local mixer_frame = function(xtouch, state)
  local frame_channels = false and {1, 2} or {1, 2, 3, 4, 5, 6, 7, 8}
  local schema = table.create {
    assign = {
      -- FRANE CONTROL
      { xtouch = 'xtouch.channel.left,press', cursor_step = -1 },
      { xtouch = 'xtouch.channel.right,press', cursor_step = 1 },
      { xtouch = 'xtouch.bank.left,press', cursor_step = -8 },
      { xtouch = 'xtouch.bank.right,press', cursor_step = 8 },
      { renoise = 'renoise.tool().app_idle_observable', callback = function(cursor, state)
          if renoise.song().transport.playing then
            local playpos = renoise.song().transport.playback_pos
            if playpos ~= last_playpos then
              xtouch:send_lcd_string(1, string.format("------%03d%03d", playpos.sequence, playpos.line))
              last_playpos = playpos
            end
          else
            local playpos = renoise.song().transport.edit_pos
            if playpos ~= last_playpos then
              xtouch:send_lcd_string(1, string.format("------%03d%03d", playpos.sequence, playpos.line))
              last_playpos = playpos
            end
          end
        end
      },
    },
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
      channels = frame_channels,
      assign = {
        -- { group = {
            -- FADER
            { fader = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].fader' end, obs = pre_post_obs, value = pre_post_value },
            -- SELECT
            { obs = function(cursor, state) return 'renoise.song().selected_track_index_observable -- ' .. cursor.channel end,
              led = function(cursor, state) return xtouch.channels[cursor.channel].select.led end,
              value = function(cursor, state) return renoise.song().selected_track_index end,
              to_led = function(cursor, state)
                local is_current = renoise.song().selected_track_index == cursor.track
                if cursor.channel == 1 then
                  return is_current and 2 or renoise.song().selected_track_index < cursor.track and 1 or 0
                elseif cursor.channel == 8 then
                  return is_current and 2 or renoise.song().selected_track_index > cursor.track and 1 or 0
                else
                  return is_current and 2 or 0
                end
              end
            },
            { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].select,press' end,
              callback = function(cursor, state) renoise.song().selected_track_index = cursor.track end
            },
            -- VU LEDS
            { vu = function(cursor, state) return cursor.channel end,
              track = function(cursor, state) return cursor.track end,
              at = function(cursor, state) return not renoise.app().window.mixer_view_post_fx and 2 or nil end,
              post = function(cursor, state) return renoise.app().window.mixer_view_post_fx end
            },
            -- SCREEN
            { screen = function(cursor, state) return xtouch.channels[cursor.channel].screen end, render = render_track_name,
              trigger = function(cursor, state) return 'renoise.song().tracks[' .. cursor.track .. '].name_observable' end,
              value = function(cursor, state) return renoise.song().tracks[cursor.track] end,
            },
            -- MUTE
            { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].mute,press' end,
              callback = function(cursor, state) renoise.song().tracks[cursor.track].mute_state = 4 - renoise.song().tracks[cursor.track].mute_state end,
            },
            { obs = function(cursor, state) return 'renoise.song().tracks[' .. cursor.track .. '].mute_state_observable' end,
              value = function(cursor, state)
                -- rprint(cursor)
                -- oprint(renoise.song().tracks[cursor.track])
                return renoise.song().tracks[cursor.track].mute_state
              end,
              led = function(cursor, state) return xtouch.channels[cursor.channel].mute.led end,
              to_led = function(cursor, state, v) return v == 3 and 2 or 0 end
            },
            -- SOLO
            { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].solo,press' end,
              callback = function(cursor, state) renoise.song().tracks[cursor.track].solo_state = not renoise.song().tracks[cursor.track].solo_state end,
            },
            { obs = function(cursor, state) return 'renoise.song().tracks[' .. cursor.track .. '].solo_state_observable' end,
              value = function(cursor, state) return renoise.song().tracks[cursor.track].solo_state end,
              led = function(cursor, state) return xtouch.channels[cursor.channel].solo.led end
            }
          }
        -- }
      -- },
      -- refresh_on = function(cursor, state) return 'renoise.song().tracks_observable' end
    }
  }

  plug_schema(schema, pot_and_leds_panning(xtouch))

  return schema
end


return function(xtouch, state)
  return table.create {
    name = 'Mixer',
    number = 1,

    state = renoise.Document.create('mixer_state') {
      -- current_schema = renoise.Document.ObservableString(''),
      modifiers = {
        shift = renoise.Document.ObservableBoolean(false),
        option = renoise.Document.ObservableBoolean(false),
        control = renoise.Document.ObservableBoolean(false),
        alt = renoise.Document.ObservableBoolean(false),
      },
      current_param = {1, 1, 1, 1, 1, 1, 1, 1},
      current_track = renoise.song().selected_track_index,
      current_device = 1,
    },

    schemas = {
      mixer_frame = mixer_frame,
      device_frame = device_frame,
      base = base
    },

    startup = { 'base', 'mixer_frame' }
  }
end
