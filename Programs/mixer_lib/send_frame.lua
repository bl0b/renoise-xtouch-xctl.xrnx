function pos_and_dest(cursor, state)
  -- print('pos_and_dest', cursor.channel, cursor.send.index, cursor.send.device)
  -- rprint(cursor.send.state)
  return {
    id = 'pos&dest',
    channel = cursor.channel,
    line1 = cursor.send.device and string.format('% 7s', '#' .. cursor.send.index.value) or 'Click',
    line2 = cursor.send.device and strip_vowels(get_send_track(cursor.send.device:parameter(3).value).name) or 'to add',
    inverse = false,
    color = cursor.send.device and get_send_track(cursor.send.device:parameter(3).value).color or {255, 255, 255}
  }
end



function update_send_config(config)
  return string.format([[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="12">
  <DeviceSlot type="SendDevice">
    <IsMaximized>%s</IsMaximized>
    <SendAmount><Value>%f</Value></SendAmount>
    <SendPan><Value>%f</Value></SendPan>
    <DestSendTrack><Value>%f</Value></DestSendTrack>
    <MuteSource>%s</MuteSource>
    <SmoothParameterChanges>true</SmoothParameterChanges>
    <ApplyPostVolume>%s</ApplyPostVolume>
  </DeviceSlot>
</FilterDevicePreset>]], config.is_maximized.value and 'true' or 'false', config.send_amount.value, config.send_pan.value, config.receiver.value, config.mute_source.value and 'true' or 'false', config.apply_post_vol.value and 'true' or 'false')
end

local ObservableNumber = renoise.Document.ObservableNumber
local ObservableBang = renoise.Document.ObservableBang
local ObservableString = renoise.Document.ObservableString
local ObservableBoolean = renoise.Document.ObservableBoolean


function get_send_config(device)
  -- print('get_send_config', device)
  if device == nil then return {} end
  local ret = {
    is_maximized = ObservableBoolean(),
    send_amount = ObservableNumber(),
    send_pan = ObservableNumber(),
    receiver = ObservableNumber(),
    mute_source = ObservableBoolean(),
    apply_post_vol = ObservableBoolean(),
  }

  local update_observables = function()
    local data = device.active_preset_data:gsub('[ \r\n\t]+', '')
    local extract = function(re) return data:gmatch(re)() end
    ret.is_maximized.value = extract('IsMaximized>([^<]+)') == 'true'
    ret.send_amount.value = device:parameter(1).value
    ret.send_pan.value = device:parameter(2).value
    ret.receiver.value = device:parameter(3).value
    ret.mute_source.value = extract('MuteSource>([^<]+)') == 'true'
    ret.apply_post_vol.value = extract('ApplyPostVolume>([^<]+)') == 'true'
    -- rprint(ret)
  end

  local update_device = function()
    device.active_preset_data = update_send_config(ret)
  end

  update_observables()
  for k, v in pairs(ret) do v:add_notifier(update_device) end
  device.active_preset_observable:add_notifier(update_observables)

  ret.terminate = function()
    -- print('terminate!', device.display_name)
    device.active_preset_data:remove_notifier(update_observables)
    for k, v in pairs(ret) do ret[v]:remove_notifier(update_device) end
  end

  return ret
end

function get_send_track(n)
  local s = renoise.song()
  local first_send = s.sequencer_track_count + 2
  return s:track(first_send + n)
end

function send_frame(xtouch, s)
  local dummy = ObservableBang()
  local current_sends = {}
  return table.create {
    assign = {
      { xtouch = 'xtouch.channel.left,press', cursor_step = -1 },
      { xtouch = 'xtouch.channel.right,press', cursor_step = 1 },
      { xtouch = 'xtouch.bank.left,press', cursor_step = -8 },
      { xtouch = 'xtouch.bank.right,press', cursor_step = 8 },
    },
    frame = {
      name = 'send',
      values = function(cursor, state)
        local t = renoise.song().selected_track
        for i = 1, #current_sends do if current_sends[i].state and current_sends[i].terminate then current_sends[i].state.terminate() end end
        table.clear(current_sends)
        for i = 2, #t.devices do
          local d = t:device(i)
          if d.name == '#Send' and d.display_name:sub(1, 8) ~= 'XT Tap #' then
            current_sends[#current_sends + 1] = {index = ObservableNumber(i), device = d, state = get_send_config(d)}
          end
        end
        current_sends[#current_sends + 1] = {index = ObservableNumber(#t.devices + 1)}  -- always have one free slot
        for i = #current_sends + 1, 8 do
          current_sends[i] = {index = ObservableNumber(#t.devices + 1)}
        end
        return current_sends
      end,
      channels = {1, 2, 3, 4, 5, 6, 7, 8},
      assign = {
        { fader = 'xtouch.channels[cursor.channel].fader',
          obs = 'cursor.send.device and cursor.send.state.send_amount',
          value = 'cursor.send.device and cursor.send.state.send_amount',
          to_fader = function(cursor, state, value) return to_fader_device_param(xtouch, nil, cursor.send.device:parameter(1), value) end,
          from_fader = function(cursor, state, value) return from_fader_device_param(xtouch, nil, cursor.send.device:parameter(1), value) end,
          description = 'Send Amount'
        },
        -- ENCODER LED
        { led = 'xtouch.channels[cursor.channel].encoder.led',
          obs = 'cursor.send.device and cursor.send.state.send_pan -- led strip',
          value = function(cursor, state) return cursor.send.device and cursor.send.state.send_pan.value end,
          to_led = led_center_strip
        },
        -- -- ENCODER
        -- { xtouch = 'xtouch.channels[cursor.channel].encoder,delta',
        --   callback = function(cursor, state)
        --     -- print('encoder delta', cursor.channel, cursor.param)
        --     local p = cursor.param
        --     if p == nil or p.name == nil then return end
        --     local q = p.value_quantum
        --     if q == 0 then q = (p.value_max - p.value_min) * 0.01 end
        --     local v = p.value + q * xtouch.channels[cursor.channel].encoder.delta.value
        --     if v > p.value_max then v = p.value_max end
        --     if v < p.value_min then v = p.value_min end
        --     p.value = v
        --   end
        -- },
        -- SCREEN
        { obs = 'cursor.send.index -- strip', scribble = pos_and_dest, immediate = true },
        { obs = 'cursor.send.device and cursor.send.state.receiver -- strip', scribble = pos_and_dest, immediate = true },
        { obs = 'cursor.send.device and cursor.send.state.send_amount -- strip',
          scribble = function(cursor, state)
            return {
              id = 'send amount popup',
              channel = cursor.channel,
              line1 = 'Amount',
              line2 = format_value(cursor.send.device:parameter(1).value_string),
              inverse = false,
              color = get_send_track(cursor.send.device:parameter(3).value).color or {255, 255, 255},
              ttl = xtouch.program_config.popup_duration.value
            }
          end,
        },
        { obs = 'cursor.send.device and cursor.send.state.send_pan -- strip',
          scribble = function(cursor, state)
            return {
              id = 'send pan popup',
              channel = cursor.channel,
              line1 = 'Panning',
              line2 = format_value(cursor.send.device:parameter(2).value_string),
              inverse = false,
              color = get_send_track(cursor.send.device:parameter(3).value).color or {255, 255, 255},
              ttl = xtouch.program_config.popup_duration.value
            }
          end,
        },
        { xtouch = 'xtouch.channels[cursor.channel].encoder,click',
          callback = function(cursor, state)
            if cursor.send.device == nil then
              local t = renoise.song().selected_track
              t:insert_device_at('Audio/Effects/Native/#Send', #t.devices + 1)
            end
          end,
          description = 'Create a send device'
        },

        { xtouch = 'xtouch.channels[cursor.channel].mute,press',
          callback = function(cursor, state)
            if cursor.send.device == nil then return end
            cursor.send.state.mute_source.value = not cursor.send.state.mute_source.value
          end,
          description = 'Toggle mute source'
        },
        { obs = 'cursor.send.device and cursor.send.state.mute_source or dummy',
          led = 'xtouch.channels[cursor.channel].mute.led',
          value = function(cursor, state) return cursor.send.device and cursor.send.state.mute_source.value end,
          to_led = function(cursor, state, v) return v and 2 or 0 end
        },

        { xtouch = 'xtouch.channels[cursor.channel].select,press',
          callback = function(cursor, state)
            if cursor.send.device == nil then return end
            cursor.send.device.is_active = not cursor.send.device.is_active
          end,
          description = 'Toggle bypass'
        },
        { obs = 'cursor.send.device and cursor.send.device.is_active_observable or dummy',
          led = 'xtouch.channels[cursor.channel].select.led',
          value = function(cursor, state) return cursor.send.device and cursor.send.device.is_active end,
          to_led = function(cursor, state, v) return v and 2 or 0 end
        },

        { xtouch = 'xtouch.channels[cursor.channel].solo,press',
          callback = function(cursor, state)
            if cursor.send.device == nil then return end
            cursor.send.state.apply_post_vol.value = not cursor.send.state.apply_post_vol.value
          end,
          description = 'Toggle apply post mixer vol&pan'
        },
        { obs = 'cursor.send.device and cursor.send.state.apply_post_vol or dummy',
          led = 'xtouch.channels[cursor.channel].solo.led',
          value = function(cursor, state) return cursor.send.device and cursor.send.state.apply_post_vol.value end,
          to_led = function(cursor, state, v) return v and 2 or 0 end
        },

        { obs = 'dummy', led = 'xtouch.channels[cursor.channel].rec.led', value = function() return 0 end, to_led = function() return 0 end},
        
        { xtouch = 'xtouch.channels[cursor.channel].encoder,delta',
          callback = function(cursor, state)
            -- print("SHIFT=" .. (state.modifiers.shift.value and 'true' or 'false') .. " CONTROL=" .. (state.modifiers.control.value and 'true' or 'false'))
            if not cursor.send.device then return end

            local delta = xtouch.channels[cursor.channel].encoder.delta.value
            if delta == 0 then return false end

            -- SHIFT: change receiver
            if state.modifiers.shift.value then
              if not (cursor.send.device ~= nil and delta ~= 0) then return false end

              local t = cursor.send.state.receiver.value
              local s = renoise.song()
              local nt = s.send_track_count
              local next_track

              if delta > 0 then
                if t == nt then return false end
                next_track = (function() for i = t + 1, nt - 1 do if s:track(s.sequencer_track_count + 2 + i).name:sub(1, 5) ~= 'XT VU' then return i end end end)()
              else
                if t == 0 then return false end
                next_track = (function() for i = t - 1 , 0, -1 do if s:track(s.sequencer_track_count + 2 + i).name:sub(1, 5) ~= 'XT VU' then return i end end end)()
              end

              if next_track and next_track ~= cursor.send.state.receiver.value then cursor.send.state.receiver.value = next_track end

              -- CONTROL: move
            elseif state.modifiers.control.value then
              local t = renoise.song().selected_track
              if delta > 0 then
                if cursor.send.index.value == #t.devices then return false end
                t:swap_devices_at(cursor.send.index.value, cursor.send.index.value + 1)
                cursor.send.index.value = cursor.send.index.value + 1
              else
                if cursor.send.index.value == 2 then return false end
                t:swap_devices_at(cursor.send.index.value - 1, cursor.send.index.value)
                cursor.send.index.value = cursor.send.index.value - 1
              end

            -- DEFAULT: pan
            else
              local q = 0.01
              local v = cursor.send.state.send_pan.value + q * delta
              cursor.send.state.send_pan.value = v > 1 and 1 or v > 0 and v or 0
            end
          end,
          description = 'Panning\nDestination (SHIFT)\nMove in chain (CONTROL)'
        },
        { obs = 'cursor.send.device and cursor.send.device:parameter(2).value_observable',
          value = function(cursor, state) return cursor.send.device and cursor.send.device:parameter(2).value end,
          led = 'xtouch.channels[cursor.channel].encoder.led',
          to_led = led_center_strip
        },
        { xtouch = 'xtouch.channels[cursor.channel].encoder,long_press',
          frame = 'update',
          before = function(cursor, state)
            -- print('pouet send delete')
            if cursor.send.device then
              renoise.song().selected_track:delete_device_at(cursor.send.index.value)
              return
            else
              xtouch.schema_manager:select_page('Devices')
            end
            return false
          end,
          description = 'Delete send device'
        },
        -- { renoise = 'cursor.send.device and cursor.send.device.active_preset_observable -- refresh sends',
        --   frame = 'update',
        --   after = function(cursor, state)
        --     local d = cursor.send.device
        --     if not d then return end
        --     -- print(d.active_preset_data)
        --     xtouch.channels[cursor.channel].mute.led.value = d.active_preset_data:find('<MuteSource>t') ~= nil and 2 or 0
        --   end
        -- },
        { renoise = 'renoise.song().selected_track.devices_observable -- refresh sends', frame = 'update' },
        { renoise = 'renoise.song().selected_track_observable -- refresh sends', frame = 'update' },
      }
    }
  }
end
