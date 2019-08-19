function channel_bindings(xtouch, chan, device, restrict_params, screen_func)
  local encoder_callback
  local get_param = function(cursor, state)
    return find_device_parameter(renoise.song().selected_track_index,
                                 device or cursor.device,
                                 state.current_param[chan or cursor.channel].value)
  end

  if restrict_params == nil then
    encoder_callback = function(cursor, state)
      rprint(cursor)
      print(renoise.song().selected_track_index)
      local t = renoise.song().tracks[renoise.song().selected_track_index]
      print(#t.devices, cursor.device)
      if cursor.device > #t.devices then
        return
      end
      local d = t.devices[cursor.device]
      local i = state.current_param[chan].value
      i = i + xtouch.channels[chan].encoder.delta
      if i < 1 then i = 1 end
      if i > #restrict_params then i = #d.parameters end
      state.current_param[chan].value = restrict_params[i]
    end
  else
    encoder_callback = function(cursor, state)
      rprint(cursor)
      print(renoise.song().selected_track_index)
      local t = renoise.song().tracks[renoise.song().selected_track_index]
      print(#t.devices, cursor.device)
      if cursor.device > #t.devices then
        return
      end
      local d = t.devices[cursor.device]
      local i = state.current_param[chan].value
      i = i + xtouch.channels[chan].encoder.delta
      if i < 1 then i = 1 end
      if i > #d.parameters then i = #d.parameters end
      state.current_param[chan].value = i
    end
  end

  local t = table.create {
    { fader = function(cursor, state) return 'xtouch.channels[' .. (chan or cursor.channel) .. '].fader' end,
      obs = function(cursor, state)
        return ('renoise.song().tracks[' .. renoise.song().selected_track_index ..
                '].devices[' .. (device or cursor.device) ..
                '].parameters[' .. state.current_param[chan or cursor.channel].value ..
                '].value_observable')
      end,
      value = function(cursor, state)
        local p = get_param(cursor, state)
        if p ~= nil then return p end
      end,
      to_fader = function(cursor, state, value)
        local p = get_param(cursor, state)
        if p == nil then return end
        local min = p.value_min
        local max = p.value_max
        local ret = (value - min) / (max - min)
        if ret < min then ret = min end
        if ret > max then ret = max end
        return ret
      end,
      from_fader = function(cursor, state, value)
        local p = get_param(cursor, state)
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
    { screen = function(cursor, state) return xtouch.channels[chan or cursor.channel].screen end, render = screen_func,
      trigger = function(cursor, state) return 'renoise.song().tracks[' .. renoise.song().selected_track_index .. '].devices_observable' end,
      value = function(cursor, state) return renoise.song().selected_track end,
    },
    { xtouch = function(cursor, state) return 'xtouch.channels[' .. (chan or cursor.channel) .. '].encoder,delta' end,
      frame = 'update',
      callback = encoder_callback
    },
    { xtouch = function(cursor, state) return 'xtouch.channels[' .. (chan or cursor.channel) .. '].encoder,press' end,
      schema = 'param_frame',
      callback = function(cursor, state) renoise.song().selected_device_index = (device or cursor.device) end
    }
  }

  rprint(t)
  return t
end





function device_frame(xtouch, s)
  return table.create {
    assign = TableConcat(
              TableConcat(
                channel_bindings(xtouch, 1, 1, {1, 2, 3}, render_track_and_parameter_name),
                channel_bindings(xtouch, 8, 1, {4, 5}, render_parameter_name)),
              {
                { xtouch = 'xtouch.channel.left,press', cursor_step = -1 },
                { xtouch = 'xtouch.channel.right,press', cursor_step = 1 },
                { xtouch = 'xtouch.bank.left,press', cursor_step = -8 },
                { xtouch = 'xtouch.bank.right,press', cursor_step = 8 },
              }),
    frame = {
      name = 'device',
      values = function(cursor, state)
        local ret = table.create {}
        print('current track', renoise.song().selected_track_index)
        for i = 2, #renoise.song().tracks[renoise.song().selected_track_index].devices do ret:insert(i) end
        return ret
      end,
      channels = {2, 3, 4, 5, 6, 7},
      before = function(frame, state) for i = 1, 8 do xtouch:untap(i) end end,
      after = function(channels, values, start, state)
        local max = #values - start + 1
        if max > #channels then max = #channels end
        print("Have", #channels, "channels and", #values, "values. start =", start, "max =", max)
        xtouch:tap(renoise.song().selected_track_index, #renoise.song().tracks[renoise.song().selected_track_index].devices + 1, 8, false)
        for i = max, 1, -1 do
          xtouch:tap(renoise.song().selected_track_index, start + i, channels[i], false)
        end
        xtouch:tap(renoise.song().selected_track_index, 2, 1, false)
      end,
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
        },
        { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].encoder,press' end,
          schema = 'param_frame',
          callback = function(cursor, state) renoise.song().selected_device_index = cursor.device end
        }
      }
    }
  }
end
