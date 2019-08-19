local last_d

function param_frame(xtouch, s)
  return table.create {
    assign = {
      { xtouch = 'xtouch.channel.left,press', cursor_step = -1 },
      { xtouch = 'xtouch.channel.right,press', cursor_step = 1 },
      { xtouch = 'xtouch.bank.left,press', cursor_step = -8 },
      { xtouch = 'xtouch.bank.right,press', cursor_step = 8 },
      { renoise = 'renoise.tool().app_idle_observable', callback = function(cursor, state)
          if last_d ~= renoise.song().selected_device_index then
            if renoise.song().selected_device then
              xtouch:send_lcd_string(1, string.format("%02d%02d-%s", renoise.song().selected_track_index, renoise.song().selected_device_index, strip_vowels(renoise.song().selected_device.name)))
            end
            last_d = renoise.song().selected_device_index
          end
        end
      },
    },
    frame = {
      name = 'param',
      values = function(cursor, state)
        local ret = table.create {}
        if renoise.song().selected_device == nil then return ret end
        local device = renoise.song().selected_device
        for i = 1, #device.parameters do ret:insert(i) end
        return ret
      end,
      channels = {1, 2, 3, 4, 5, 6, 7, 8},
      assign = {
        { fader = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].fader' end,
          obs = function(cursor, state)
            return 'renoise.song().selected_device.parameters[' .. cursor.param .. '].value_observable'
          end,
          value = function(cursor, state) return renoise.song().selected_device.parameters[cursor.param] end,
          to_fader = function(cursor, state, value)
            local p = renoise.song().selected_device.parameters[cursor.param]
            if p == nil then return end
            local min = p.value_min
            local max = p.value_max
            local ret = (value - min) / (max - min)
            if ret < min then ret = min end
            if ret > max then ret = max end
            return ret
          end,
          from_fader = function(cursor, state, value)
            local p = renoise.song().selected_device.parameters[cursor.param]
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
        { screen = function(cursor, state) return xtouch.channels[cursor.channel].screen end, render = render_parameter_name,
          trigger = function(cursor, state) return 'renoise.song().selected_device_observable' end,
          value = function(cursor, state) return renoise.song().selected_track end,
        },
        { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].encoder,press' end,
          schema = 'device_frame',
          callback = function(cursor, state) renoise.song().selected_device_index = 0 end
        }
      }
    }
  }
end
