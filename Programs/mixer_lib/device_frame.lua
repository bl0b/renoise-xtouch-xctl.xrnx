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
      { obs = 'renoise.song():track(renoise.song().selected_track_index).prefx_panning.value_observable',
        scribble = function(cursor, state)
          return {
            id = 'panning popup',
            channel = 1,
            ttl = xtouch.program_config.popup_duration.value,
            line1 = 'Pre Pan',
            line2 = format_value(renoise.song():track(renoise.song().selected_track_index).prefx_panning.value_string)
          }
        end
      },
      -- SCREEN
      { obs = 'renoise.song().selected_track.name_observable -- channel 1',
        scribble = function(cursor, state)
          local t = renoise.song().selected_track
          return {
            id = 'track name',
            channel = 1,
            line1 = 'PRE (P)',
            line2 = strip_vowels(t.name),
            inverse = false,
            color = t.color
          }
        end,
        description = "Track name",
        immediate = true,
      },
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
      { obs = 'renoise.song():track(renoise.song().selected_track_index).prefx_width.value_observable',
        scribble = function(cursor, state)
          return {
            id = 'width popup',
            channel = 1,
            ttl = xtouch.program_config.popup_duration.value,
            line1 = 'Width',
            line2 = format_value(renoise.song():track(renoise.song().selected_track_index).prefx_width.value_string)
          }
        end
      },
      -- SCREEN
      { obs = 'renoise.song().selected_track.name_observable -- channel 1',
        scribble = function(cursor, state)
          local t = renoise.song().selected_track
          return {
            id = 'track name',
            channel = 1,
            line1 = 'PRE (W)',
            line2 = strip_vowels(t.name),
            inverse = false,
            color = t.color
          }
        end,
        description = "Track name",
        immediate = true,
      },
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
      { xtouch = 'xtouch.modify.shift,press -- DevicesWidth', page = 'DevicesWidth' },
      { xtouch = 'xtouch.modify.shift,release -- Devices', page = 'Devices' },
      { xtouch = 'xtouch.left,press',
        frame = 'update',
        before = function(cursor, state)
          local tracks = all_usable_track_indices()
          local si = table.find(tracks, renoise.song().selected_track_index)
          if si and si > 1 then renoise.song().selected_track_index = tracks[si - 1] end
        end,
        description = 'Select previous track'
      },
      { xtouch = 'xtouch.right,press',
        frame = 'update',
        before = function(cursor, state)
          local tracks = all_usable_track_indices()
          local si = table.find(tracks, renoise.song().selected_track_index)
          if si and si < #tracks then renoise.song().selected_track_index = tracks[si + 1] end
        end,
        description = 'Select next track'
      },

      { renoise = 'renoise.song().selected_track_observable -- LCD track name',
        callback = function(cursor, state)
            xtouch:send_lcd_string(1, string.format("%02d%s", renoise.song().selected_track_index, renoise.song().selected_track.name))
        end,
        immediate = true
      },

      -- channel 1
      { fader = 'xtouch.channels[1].fader',
        obs = 'renoise.song().selected_track.prefx_volume.value_observable -- device frame',
        value = function(cursor, state) return renoise.song().selected_track.prefx_volume end,
        to_fader = function(cursor, state, value) return to_fader_device_param(xtouch, renoise.song().selected_track:device(1), 2, value) end,
        from_fader = function(cursor, state, value) return from_fader_device_param(xtouch, renoise.song().selected_track:device(1), 2, value) end,
        description = 'Pre Gain'
      },
      { obs = 'renoise.song():track(renoise.song().selected_track_index).prefx_volume.value_observable -- device frame',
        scribble = function(cursor, state)
          return {
            id = 'volume popup',
            channel = 1,
            ttl = xtouch.program_config.popup_duration.value,
            line1 = 'Pre Vol',
            line2 = format_value(renoise.song():track(renoise.song().selected_track_index).prefx_volume.value_string)
          }
        end
      },
      -- VU LEDS
      { vu = 1,
        track = 'renoise.song().selected_track',
        right_of = 'renoise.song().selected_track:device(1)',
        post = false,
        description = "Pre signal level"
      },
      -- ENCODER CLICK : SENDS
      { xtouch = 'xtouch.channels[1].encoder,click', page = 'Mix' },

      -- channel 8
      -- FADER
      { fader = 'xtouch.channels[8].fader -- device frame',
        obs = 'renoise.song().selected_track.postfx_volume.value_observable -- device frame',
        value = function(cursor, state) return find_device_parameter(renoise.song().selected_track_index, 1, 5) end,
        to_fader = function(cursor, state, value) return to_fader_device_param(xtouch, renoise.song().selected_track:device(1), 5, value) end,
        from_fader = function(cursor, state, value) return from_fader_device_param(xtouch, renoise.song().selected_track:device(1), 5, value) end,
        description = "Post Gain"
      },
      { obs = 'renoise.song():track(renoise.song().selected_track_index).postfx_volume.value_observable -- device frame',
        scribble = function(cursor, state)
          return {
            id = 'volume popup',
            channel = 8,
            ttl = xtouch.program_config.popup_duration.value,
            line1 = 'PostVol',
            line2 = format_value(renoise.song():track(renoise.song().selected_track_index).postfx_volume.value_string)
          }
        end
      },
      -- ENCODER
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
      { obs = 'renoise.song().selected_track.postfx_panning.value_observable -- popup',
        scribble = function(cursor, state)
          return {
            id = 'volume popup',
            channel = 8,
            ttl = xtouch.program_config.popup_duration.value,
            line1 = 'PostPan',
            line2 = format_value(renoise.song():track(renoise.song().selected_track_index).postfx_panning.value_string)
          }
        end
      },
      { obs = 'renoise.song().selected_track.postfx_panning.value_observable -- led strip',
        value = function(cursor, state) return renoise.song():track(renoise.song().selected_track_index).prefx_panning.value end,
        led = function(cursor, state) return xtouch.channels[8].encoder.led end,
        to_led = led_center_strip
      },
      -- SCREEN
      { obs = 'renoise.song().selected_track.name_observable -- channel 8',
        scribble = function(cursor, state)
          local t = renoise.song().selected_track
          return {
            id = 'track name',
            channel = 8,
            line1 = '   POST',
            line2 = strip_vowels(t.name),
            inverse = false,
            color = t.color
          }
        end,
        description = "Track name",
        immediate = true,
      },
      -- VU LEDS
      { vu = 8,
        track = 'renoise.song().selected_track',
        right_of = nil,
        post = true,
        description = "Post signal level"
      },
      -- ENCODER CLICK : SENDS
      { xtouch = 'xtouch.channels[8].encoder,click', page = 'Sends' },
    },
    frame = {
      name = 'device',
      values = function(cursor, state)
        local ret = table.create {}
        -- print('FRAME VALUES. current track', renoise.song().selected_track_index)
        local track = renoise.song().selected_track
        for i = 2, #track.devices do
          local dev = track:device(i)
          if dev.display_name:sub(1, 8) ~= 'XT Tap #' and (dev.name ~= '#Send' or xtouch.program_config.show_sends_in_device_frame.value) then
            -- print('[xtouch] have device #' .. i .. ' «' .. track:device(i).display_name .. '» in frame values')
            ret[#ret + 1] = {
              device = track:device(i),
              param_index = renoise.Document.ObservableNumber(1),
              param = track:device(i):parameter(1)
            }
          end
        end
        for i = #ret + 1, 6 do
          -- ret[i + 1] = {display_name = '', parameter = function() end, __STRICT = function() return false end}
          ret[i] = {param={}}
        end
        return ret
      end,
      channels = {2, 3, 4, 5, 6, 7},
      assign = {
        -- { led = 'xtouch.channels[cursor.channel].solo.led', obs = 'nil -- solo led', value = 0, immediate = true },
        { led = 'xtouch.channels[cursor.channel].mute.led', obs = 'cursor.device.is_active_observable', value = function(cursor, state) return not cursor.device.is_active end, immediate = true },
        { xtouch = 'xtouch.channels[cursor.channel].mute,press', callback = function(cursor, state)
            if not cursor.device.device then return end
            cursor.device.device.is_active = not cursor.device.device.is_active
          end,
          description = 'Bypass device'
        },
        { led = 'xtouch.channels[cursor.channel].rec.led', obs = 'nil -- rec led', value = 0, immediate = true },
        { led = 'xtouch.channels[cursor.channel].select.led', obs = 'nil -- select led', value = 0, immediate = true },
        -- VU LEDS
        { vu = 'cursor.channel',
          track = 'renoise.song().selected_track',
          right_of = 'cursor.device.device',
          post = false,
          description = "Signal level output by device"
        },
        -- FADER
        { fader = 'xtouch.channels[cursor.channel].fader',
          obs = 'cursor.device.param.value_observable -- fader',
          value = function(cursor, state) return cursor.device.param end,
          to_fader = function(cursor, state, value) return to_fader_device_param(xtouch, nil, cursor.device.param, value) end,
          from_fader = function(cursor, state, value) return from_fader_device_param(xtouch, nil, cursor.device.param, value) end,
          description = 'Value of selected parameter'
        },
        { obs = 'cursor.device.param.value_observable -- popup',
          scribble = function(cursor, state)
            local p = cursor.device.device:parameter(cursor.device.param_index.value)
            if p == nil then
              return {id = 'blank', line1 = '', line2 = '', inverse = false, color = {0, 0, 0}, channel = cursor.channel}
            end
            return {
              id = 'value popup',
              channel = cursor.channel,
              line1 = strip_vowels(p.name),
              line2 = format_value(p.value_string),
              inverse = true,
              ttl = xtouch.program_config.popup_duration.value
            }
          end
        },
        -- ENCODER
        { xtouch = 'xtouch.channels[cursor.channel].encoder,delta',
          frame = 'refresh',
          before = function(cursor, state, event, widget)
            print('encoder param select BEFORE')
            if cursor.device.device == nil then return false end
            local v = cursor.device.param_index.value + xtouch.channels[cursor.channel].encoder.delta.value
            if v < 1 then v = 1 end
            if v > #cursor.device.device.parameters then v = #cursor.device.device.parameters end
            -- print(cursor.channel, cursor.device.param_index.value, #cursor.device.device.parameters, v)
            cursor.device.param_index.value = v
            cursor.device.param = cursor.device.device:parameter(v)
            print('encoder param select BEFORE returned')
          end,
          description = "Select parameter"
        },
        -- UPDATE EVENTS
        -- { renoise = 'cursor.device.param_index', frame = 'refresh',
        --   -- before = function(c, s) print('current device', c.device.device.display_name, 'current param', c.device.param_index, c.device.device:parameter(c.device.param_index)) end
        -- },
        { renoise = 'renoise.song().selected_track.devices_observable', frame = 'update' },
        { renoise = 'renoise.song().selected_track_observable', frame = 'update' },
        -- SCREEN
        { obs = 'dummy',
          scribble = function(cursor, state)
            print("param scribble strip", cursor.channel, cursor.device.device, cursor.device.param.name)
            local p = cursor.device.param
            print(p)
            if p.name == nil then return {channel = cursor.channel, color = {0, 0, 0}, id = 'blank'} end
            return {
              id = 'device&param',
              channel = cursor.channel,
              line1 = strip_vowels(cursor.device.device.display_name),
              line2 = strip_vowels(p.name),
              inverse = true,
              color = renoise.song().selected_track.color
            }
          end,
          immediate = true,
        },
        { xtouch = 'xtouch.channels[cursor.channel].encoder,click',
          page = 'Params',
          callback = function(cursor, state)
            local s = renoise.song()
            local t = s.selected_track
            s.selected_device_index = (function() for i = 2, #t.devices do if rawequal(cursor.device.device, t:device(i)) then return i end end end)()
          end
        }
      }
    }
  }
end
