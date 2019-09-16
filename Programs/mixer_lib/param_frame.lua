local last_d

function param_frame(xtouch, s)
  local dummy = renoise.Document.ObservableBang()
  return table.create {
    assign = {
      { xtouch = 'xtouch.channel.left,press', cursor_step = -1 },
      { xtouch = 'xtouch.channel.right,press', cursor_step = 1 },
      { xtouch = 'xtouch.bank.left,press', cursor_step = -8 },
      { xtouch = 'xtouch.bank.right,press', cursor_step = 8 },
      { renoise = 'dummy -- LCD',
        callback = function(cursor, state)
          -- if last_d ~= renoise.song().selected_device_index then
            -- if renoise.song().selected_device then
              xtouch:send_lcd_string(1, string.format("%02d%02d-%s", renoise.song().selected_track_index, renoise.song().selected_device_index, strip_vowels(renoise.song().selected_device.name)))
            -- end
            -- last_d = renoise.song().selected_device_index
          -- end
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
        { xtouch = 'xtouch.channels[cursor.channel].encoder,press',
          page = 'Devices',
          callback = function(cursor, state) renoise.song().selected_device_index = 0 end
        }
      }
    }
  }
end
