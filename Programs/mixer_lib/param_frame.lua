function param_frame(xtouch, s)
  local last_d, last_t

  local track_move_by = function(n)
    return function(cursor, state)
      local tracks = all_usable_track_indices()
      local si = table.find(tracks, renoise.song().selected_track_index)
      if si ~= nil then
        si = si + n
        if si > #tracks then si = #tracks end
        if si < 1 then si = 1 end
        renoise.song().selected_track_index = tracks[si]
        renoise.song().selected_device_index = 0
        renoise.song().selected_device_index = 1
      end
      xtouch.schema_manager:execute_compiled_schema_stack(xtouch.schema_manager.current_stack)
    end
  end
  
  
  local device_move_by = function(n)
    return function(cursor, state)
      local max = #renoise.song().selected_track.devices
      local di = renoise.song().selected_device_index + n
      if di > max then di = max end
      if di < 1 then di = 1 end
      renoise.song().selected_device_index = di
      xtouch.schema_manager:execute_compiled_schema_stack(xtouch.schema_manager.current_stack)
    end
  end
  
  
  local cursor_move_by = function(n, nchan)
    return function(cursor, state)
      local sm = xtouch.schema_manager
      local frame = sm.cursor._frame_param
      local max = #frame.values - nchan
      if frame == nil then return end
      frame.start = frame.start + n
      if frame.start > max then frame.start = max end
      if frame.start < 1 then frame.start = 1 end
      sm:execute_compiled_schema_stack(sm.current_stack, true)
    end
  end
  
  
  local move_by = function(n)
    local c = cursor_move_by(n, 7)
    local d = device_move_by(n)
    local t = track_move_by(n)
    return function(cursor, state)
      if     state.modifiers.control.value then d(cursor, state)
      elseif state.modifiers.shift.value   then t(cursor, state)
      else                                      c(cursor, state)
      end
    end
  end

  local dummy = renoise.Document.ObservableBang()
  
  return table.create {
    assign = {
      { xtouch = 'xtouch.channel.left,press', callback = move_by(-1, xtouch), description = 'Move frame left by 1\nSHIFT: track\nCTRL device' },
      { xtouch = 'xtouch.channel.right,press', callback = move_by(1, xtouch), description = 'Move frame right by 1\nSHIFT: track\nCTRL device' },
      { xtouch = 'xtouch.bank.left,press', callback = move_by(-8, xtouch), description = 'Move frame left by 8\nSHIFT: track\nCTRL device' },
      { xtouch = 'xtouch.bank.right,press', callback = move_by(8, xtouch), description = 'Move frame right by 8\nSHIFT: track\nCTRL device' },
      { renoise = 'renoise.tool().app_idle_observable -- LCD',
        callback = function(cursor, state)
          local s = renoise.song()
          if s.selected_device and (last_d ~= s.selected_device_index or last_t ~= s.selected_track_index) then
            last_d = s.selected_device_index
            last_t = s.selected_track_index
            xtouch:send_lcd_string(1, string.format("%02d%02d-%s", s.selected_track_index, s.selected_device_index, strip_vowels(s.selected_device.display_name)))
          end
        end,
        immediate = true
      },
    },
    frame = {
      name = 'param',
      values = function(cursor, state)
        local d = renoise.song().selected_device
        if d == nil then return {} end
        local ret = {}
        for i = 1, #d.parameters do ret[i] = d:parameter(i) end
        for i = #ret, 7 do ret[i + 1] = {value_min = 0, value_max = 1, value = 0, value_observable = dummy} end
        -- print("param values", #ret)
        -- rprint(ret)
        return ret
      end,
      channels = {1, 2, 3, 4, 5, 6, 7, 8},
      assign = {
        { fader = 'xtouch.channels[cursor.channel].fader',
          obs = 'cursor.param.value_observable',
          value = 'cursor.param',
          to_fader = function(cursor, state, value) return to_fader_device_param(xtouch, nil, cursor.param, value) end,
          from_fader = function(cursor, state, value) return from_fader_device_param(xtouch, nil, cursor.param, value) end,
          description = 'Value of parameter'
        },
        -- ENCODER LED
        { led = 'xtouch.channels[cursor.channel].encoder.led',
          obs = 'cursor.param.value_observable -- led strip',
          value = function(cursor, state) return cursor.param.value end,
          to_led = function(cursor, state, value)
            if not cursor.param.name then return 0 end
            return (
              cursor.param.polarity == renoise.DeviceParameter.POLARITY_UNIPOLAR
              and led_full_strip_lr
              or led_center_strip
            )(cursor, state, value)
          end
        },
        -- ENCODER
        { xtouch = 'xtouch.channels[cursor.channel].encoder,delta',
          callback = function(cursor, state)
            -- print('encoder delta', cursor.channel, cursor.param)
            local p = cursor.param
            if p == nil or p.name == nil then return end
            local q = p.value_quantum
            if q == 0 then q = (p.value_max - p.value_min) * 0.01 end
            local v = p.value + q * xtouch.channels[cursor.channel].encoder.delta.value
            if v > p.value_max then v = p.value_max end
            if v < p.value_min then v = p.value_min end
            p.value = v
          end,
          description = 'Change parameter value'
        },
        -- SCREEN
        { obs = 'cursor.param.value_observable -- strip param frame',
          scribble = function(cursor, state)
            -- print('param scribble', cursor.channel, cursor.param)
            if not cursor.param.name then return {color = {0, 0, 0}, id = 'blank', channel = cursor.channel} end
            return {
              id = 'param&value',
              channel = cursor.channel,
              line1 = strip_vowels(cursor.param.name),
              line2 = format_value(cursor.param.value_string),
              inverse = true,
              color = renoise.song().selected_track.color
            }
          end,
          immediate = true
        },
        { xtouch = 'xtouch.channels[cursor.channel].encoder,click',
          page = 'Devices',
          callback = function(cursor, state) renoise.song().selected_device_index = 0 end
        }
      }
    }
  }
end
