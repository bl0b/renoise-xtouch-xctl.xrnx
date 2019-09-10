
local to_fader = function(device, param, value)
  local p = device:parameter(param)
  if p == nil then return end
  local min = p.value_min
  local max = p.value_max
  local ret = (value - min) / (max - min)
  if ret < min then ret = min end
  if ret > max then ret = max end
  return ret
end

local from_fader = function(device, param, value)
  local p = device:parameter(param)
  if p == nil then return end
  local min = p.value_min
  local max = p.value_max
  local ret = min + value * (max - min)
  if ret < min then ret = min end
  if ret > max then ret = max end
  return ret
end


function device_frame_pan(xtouch, s)
  return table.create {
    assign = {
      { xtouch = 'xtouch.channels[1].encoder,delta',
        callback = function(cursor, state, event, widget)
          local track = renoise.song().selected_track_index
          local v = renoise.song():track(track).prefx_panning.value + widget.delta.value * 0.01
          v = v > 0 and v < 1 and v or v >= 1 and 1 or 0
          renoise.song():track(track).prefx_panning.value = v
          -- xtouch.channels[1].encoder.led.value = led_center_strip(cursor, state, v)
        end,
        description = "Pre Panning"
      },
      { led = xtouch.channels[1].encoder.led, to_led = led_center_strip,
        value = function(c, s) return renoise.song():track(renoise.song().selected_track_index).prefx_panning.value end,
        obs = 'renoise.song().selected_track.prefx_panning'
      },
      { xtouch = 'xtouch.modify.shift,release -- width', page = 'Devices' },
    },
  }
end


function device_frame_width(xtouch, s)
  return table.create {
    assign = {
      { xtouch = 'xtouch.channels[1].encoder,delta',
        callback = function(cursor, state, event, widget)
          local track = renoise.song().selected_track_index
          local v = renoise.song():track(track).prefx_width.value + widget.delta.value
          v = v > 0 and v < 127 and v or v >= 127 and 126 or 0
          renoise.song():track(track).prefx_width.value = v
          -- xtouch.channels[1].encoder.led.value = led_center_strip(cursor, state, v)
        end,
        description = "Pre Width"
      },
      { led = xtouch.channels[1].encoder.led, to_led = led_full_strip_lr,
        value = function(c, s) return renoise.song():track(renoise.song().selected_track_index).prefx_width.value / 126.0 end,
        obs = function(c, s) return 'renoise.song().selected_track.prefx_width' end
      },
      { xtouch = 'xtouch.modify.shift,release -- width', page = 'Devices' },
    },
  }
end


function device_frame(xtouch, s)
  return table.create {
    setup = function(cursor, state)
      xtouch:send_lcd_string(1, string.format("%02d%s", renoise.song().selected_track_index, strip_vowels(renoise.song().selected_track.name)))
    end,
    teardown = function(cursor, state)
      for i = 1, 8 do xtouch:untap(i) end
    end,
    assign = {
      { xtouch = 'xtouch.channel.left,press', cursor_step = -1 },
      { xtouch = 'xtouch.channel.right,press', cursor_step = 1 },
      { xtouch = 'xtouch.bank.left,press', cursor_step = -8 },
      { xtouch = 'xtouch.bank.right,press', cursor_step = 8 },

      -- channel 1
      { fader = 'xtouch.channels[1].fader',
        obs = 'renoise.song().selected_track.prefx_volume.value_observable',
        value = function(cursor, state) return renoise.song().selected_track.prefx_volume end,
        to_fader = function(cursor, state, value) return to_fader(renoise.song().selected_track:device(1), 2, value) end,
        description = 'Pre Gain'
      },
      { xtouch = 'xtouch.modify.shift,press -- DeviceWidth', page = 'DevicesWidth' },
      -- SCREEN
      { screen = function(cursor, state) return xtouch.channels[1].screen end, render = render_track_name,
        trigger = 'renoise.song().selected_track.name_observable -- channel 1',
        value = function(cursor, state) return renoise.song():track(renoise.song().selected_track_index) end,
        description = "Track name"
      },

      -- channel 8
      { fader = 'xtouch.channels[8].fader',
        obs = 'renoise.song().selected_track.postfx_volume.value_observable',
        value = function(cursor, state) return find_device_parameter(renoise.song().selected_track_index, 1, 5) end,
        to_fader = function(cursor, state, value) return to_fader(renoise.song().selected_track:device(1), 5, value) end,
        description = "Post Gain"
      },
      { xtouch = 'xtouch.channels[8].encoder,delta',
        callback = function(cursor, state, event, widget)
          local track = renoise.song().selected_track_index
          local v = renoise.song():track(track).postfx_panning.value + widget.delta.value * 0.01
          v = v > 0 and v < 1 and v or v >= 1 and 1 or 0
          renoise.song():track(track).postfx_panning.value = v
          xtouch.channels[8].encoder.led.value = led_center_strip(cursor, state, v)
        end,
        description = "Post Panning"
      },
      { obs = 'renoise.song().selected_track.postfx_panning.value_observable',
        value = function(cursor, state) return renoise.song():track(renoise.song().selected_track_index).prefx_panning.value end,
        led = function(cursor, state) return xtouch.channels[8].encoder.led end,
        to_led = led_center_strip
      },
      -- SCREEN
      { screen = function(cursor, state) return xtouch.channels[8].screen end, render = render_track_name,
        trigger = 'renoise.song().selected_track.name_observable -- channel 8',
        value = function(cursor, state) return renoise.song():track(renoise.song().selected_track_index) end,
        description = "Track name"
      },
    },
    frame = {
      name = 'device',
      values = function(cursor, state)
        local ret = table.create {}
        -- print('current track', renoise.song().selected_track_index)
        local track = renoise.song().selected_track
        local devs = renoise.song():track(renoise.song().selected_track_index).devices
        for i = 2, #track.devices do
          -- if devs[i].name:sub(1, 8) ~= 'XT Tap #' then
            ret:insert(track:device(i))
          -- end
        end
        return ret
      end,
      channels = {2, 3, 4, 5, 6, 7},
      before = function(frame, state)
        for i = 1, 8 do xtouch:untap(i) end
        print("Untapped")
      end,
      after = function(channels, values, start, state)
        local max = #values - start + 1
        if max > #channels then max = #channels end
        print("Have", #channels, "channels and", #values, "values. start =", start, "max =", max)
        xtouch:tap(renoise.song().selected_track_index, #renoise.song():track(renoise.song().selected_track_index).devices + 1, 8, true)
        for i = max, 1, -1 do
          xtouch:tap(renoise.song().selected_track_index, start + i + 1, channels[i], false)
        end
        xtouch:tap(renoise.song().selected_track_index, 2, 1, false)
      end,
      assign = {
        -- { vu = '', description = "Output level of associated device" },
        { fader = 'xtouch.channels[cursor.channel].fader',
          obs = 'cursor.device:parameter(state.current_param[cursor.channel].value).value_observable',
          value = function(cursor, state) return cursor.device:parameter(state.current_param[cursor.channel].value) end,
          to_fader = function(cursor, state, value) return to_fader(cursor.device, state.current_param[cursor.channel].value, value) end,
          from_fader = function(cursor, state, value) return from_fader(cursor.device, state.current_param[cursor.channel].value, value) end
        },
        -- SCREEN
        { screen = 'xtouch.channels[cursor.channel].screen', render = render_device_and_parameter_name,
          trigger = 'renoise.tool().app_idle_observable',
          value = function(cursor, state) return cursor.device end, immediate = true
        },
        { xtouch = 'xtouch.channels[cursor.channel].encoder,delta',
          frame = 'update',
          callback = function(cursor, state)
            local d = cursor.device
            local i = state.current_param[cursor.channel].value
            i = i + xtouch.channels[cursor.channel].encoder.delta
            if i < 1 then i = 1 end
            if i > #d.parameters then i = #d.parameters end
            state.current_param[cursor.channel].value = i
          end
        },
        { xtouch = 'xtouch.channels[cursor.channel].encoder,press',
          page = 'Params',
          callback = function(cursor, state)
            renoise.song().selected_device_index = cursor.device
          end
        }
      }
    }
  }
end
