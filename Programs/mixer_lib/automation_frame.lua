function automation_scribble(cursor, state)
  -- print('automation_scribble', cursor.channel)
  -- rprint(cursor.send.state)
  if not cursor.lane.automation then
    return {
      id = 'automation',
      channel = cursor.channel,
      line1 = 'Click',
      line2 = 'to add',
      inverse = false,
      color = {255, 255, 255}
    }
  end
  return {
    id = 'automation',
    channel = cursor.channel,
    line1 = string.format('%02i/%-4s', cursor.lane.track_index, strip_vowels(cursor.lane.device.display_name, 4)),
    line2 = strip_vowels(cursor.lane.param.name) or 'to add',
    inverse = false,
    color = renoise.song():track(cursor.lane.track_index).color or {255, 255, 255}
  }
end



function lane_menu_param(xtouch)
  return {
    title = 'Param',
    name = 'param',
    entries = function(cursor, state, menu)
      local d = renoise.song():track(menu.state.track_index):device(menu.state.device_index)
      local ret = {}
      for i = 1, #d.parameters do
        local t = d:parameter(i)
        if t.is_automatable then
          ret[#ret + 1] = {
            label = strip_vowels(t.name),
            value = t,
            callback = function(cursor, state, menu)
              local pattern_track = renoise.song().selected_pattern:track(menu.state.track_index)
              if not pattern_track:find_automation(menu.state.param_value) then
                pattern_track:create_automation(menu.state.param_value)
                local sm = xtouch.schema_manager
                sm:execute_compiled_schema_stack(sm.current_stack)
              end
            end
          }
        end
      end

      if #ret == 0 then
        ret = {{label = '---'}}
      end

      return ret
    end
  }
end

function lane_menu_device(xtouch)
  return {
    title = 'Device',
    name = 'device',
    entries = function(cursor, state, menu)
      local ret = {}
      local s = renoise.song()
      local t = s:track(menu.state.track_index)
      for i = 1, #t.devices do
        ret[i] = {
          label = strip_vowels(t:device(i).display_name),
          value = i,
          sub_menu = lane_menu_param(xtouch)
        }
      end
      return ret
    end
  }
end

function lane_menu_tracks(xtouch)
  return encoder_menu({
    title = 'Track',
    name = 'track',
    entries = function(cursor, state, menu)
      local s = renoise.song()
      local ret = {}
      for i = 1, 1 + s.sequencer_track_count + s.send_track_count do
        ret[i] = {
          label = strip_vowels(s:track(i).name),
          value = i,
          sub_menu = lane_menu_device(xtouch)
        }
      end
      return ret
    end
  })
end


function playmode_short(mode)
  if mode == renoise.PatternTrackAutomation.PLAYMODE_POINTS then return 'Pt'
  elseif mode == renoise.PatternTrackAutomation.PLAYMODE_LINES then return 'Ln'
  elseif mode == renoise.PatternTrackAutomation.PLAYMODE_CURVES then return 'Cu'
  end
end


function lane(xtouch, automation, ti)
  if automation ~= nil then
    local ret = {
      automation = automation,
      track_index = ti,
      device = automation.dest_device,
      param = automation.dest_parameter,
      recording = renoise.Document.ObservableBoolean(false),
      fader_value = renoise.Document.ObservableNumber(automation.dest_parameter.value),
      last_edit_line = -1,
      points = nil,
    }

    ret.menu = encoder_menu({
      title = 'Autom.',
      name = 'autom',
      entries = function() return {
        { label = 'Mode:' .. playmode_short(automation.playmode),
          sub_menu = {
            title = 'PlMode',
            name = 'playmode',
            entries = function() return {
              {label = 'Points', callback = function() automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS end},
              {label = 'Lines',  callback = function() automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_LINES  end},
              {label = 'Curves', callback = function() automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_CURVES end},
            } end,
          }
        },
        { label = '---', },
        { label = 'CLEAR',
          callback = function()
            automation:clear()
            local sm = xtouch.schema_manager
            sm:execute_compiled_schema_stack(sm.current_stack)
          end,
        },
        { label = 'DELETE',
          callback = function()
            renoise.song().selected_pattern:track(ti):delete_automation(automation.dest_parameter)
            local sm = xtouch.schema_manager
            sm:execute_compiled_schema_stack(sm.current_stack)
          end,
        },
      } end
    })

    ret.terminate = function()
      if ret.points ~= nil then
        ret.automation.points = ret.points
      end
    end

    return ret
  else
    return {menu = lane_menu_tracks(xtouch)}
  end
end


function automation_frame(xtouch, state)
  local dummy = renoise.Document.ObservableBang()
  local current_lanes = {}
  return with_menu_mappings(xtouch, {
    assign = {
      { xtouch = 'xtouch.channel.left,press', cursor_step = -1 },
      { xtouch = 'xtouch.channel.right,press', cursor_step = 1 },
      { xtouch = 'xtouch.bank.left,press', cursor_step = -8 },
      { xtouch = 'xtouch.bank.right,press', cursor_step = 8 },

      { xtouch = 'xtouch.automation.read_off,press',
        callback = function(cursor, state) state.automation.mode.value = 'read' end,
      },
      { xtouch = 'xtouch.automation.write,press',
        callback = function(cursor, state) state.automation.mode.value = 'write' end,
      },
      { xtouch = 'xtouch.automation.trim,press',
        callback = function(cursor, state) state.automation.mode.value = 'trim' end,
      },
      { xtouch = 'xtouch.automation.touch,press',
        callback = function(cursor, state) state.automation.mode.value = 'touch' end,
      },
      { xtouch = 'xtouch.automation.latch,press',
        callback = function(cursor, state) state.automation.mode.value = 'latch' end,
      },
      { xtouch = 'xtouch.automation.group,press',
        callback = function(cursor, state) state.automation.all_tracks.value = not state.automation.all_tracks.value end,
      },

      { obs = 'state.automation.all_tracks -- group',
        led = xtouch.automation.group.led,
        value = function(c, s) return s.automation.all_tracks.value end,
        to_led = function(c, s, v) return v and 2 or 0 end,
      },
      { obs = 'state.automation.mode -- read',
        led = xtouch.automation.read_off.led,
        value = function(c, s) return s.automation.mode.value == 'read' end,
        to_led = function(c, s, v) return v and 2 or 0 end,
      },
      { obs = 'state.automation.mode -- write',
        led = xtouch.automation.write.led,
        value = function(c, s) return s.automation.mode.value == 'write' end,
        to_led = function(c, s, v) return v and 2 or 0 end,
      },
      { obs = 'state.automation.mode -- trim',
        led = xtouch.automation.trim.led,
        value = function(c, s) return s.automation.mode.value == 'trim' end,
        to_led = function(c, s, v) return v and 2 or 0 end,
      },
      { obs = 'state.automation.mode -- touch',
        led = xtouch.automation.touch.led,
        value = function(c, s) return s.automation.mode.value == 'touch' end,
        to_led = function(c, s, v) return v and 2 or 0 end,
      },
      { obs = 'state.automation.mode -- latch',
        led = xtouch.automation.latch.led,
        value = function(c, s) return s.automation.mode.value == 'latch' end,
        to_led = function(c, s, v) return v and 2 or 0 end,
      },

      { renoise = 'renoise.song().selected_pattern_observable -- update', frame = 'update' },
      { renoise = 'renoise.song().selected_pattern_track_observable -- update', frame = 'update' },
      { renoise = 'state.automation.all_tracks -- update', frame = 'update' },
      { renoise = 'renoise.song().selected_sequence_index_observable', frame='update' },
    },

    frame = {
      name = 'lane',
      channels = {1, 2, 3, 4, 5, 6, 7, 8},
      values = function(cursor, state)
        for i = 1, #current_lanes do
          local l = current_lanes[i]
          if l.terminate ~= nil then l.terminate() end
        end
        table.clear(current_lanes)
        local s = renoise.song()
        local pattern = s.selected_pattern
        if state.automation.all_tracks then
          for ti = 1, #s.tracks do
            for ai = 1, #s.selected_pattern.tracks[ti].automation do
              local automation = s.selected_pattern.tracks[ti].automation[ai]
              current_lanes[#current_lanes + 1] = lane(xtouch, automation, ti)
            end
          end
        else
          for ai = 1, #s.selected_pattern_track.automation do
            local automation = s.selected_pattern_track.automation[ai]
            current_lanes[#current_lanes + 1] = lane(xtouch, automation, s.selected_track_index)
          end
        end
        current_lanes[#current_lanes + 1] = lane(xtouch)
        for ai = #current_lanes + 1, 8 do
          current_lanes[#current_lanes + 1] = lane(xtouch)
        end
        return current_lanes
      end,

      assign = {
        { fader = 'cursor.lane.automation and xtouch.channels[cursor.channel].fader or nil',
          obs = 'cursor.lane.param and cursor.lane.fader_value',
          value = 'cursor.lane.param and cursor.lane.fader_value',
          to_fader = function(cursor, state, value) return value end,
          from_fader = function(cursor, state, value) return value end,
        },

        { renoise = 'cursor.lane.automation and cursor.lane.fader_value or nil',
          callback = function(cursor, state)
            if not xtouch.channels[cursor.channel].fader.state.value then return end
            local mode = state.automation.mode.value
            if mode == 'read' or not cursor.lane.recording.value then return end
            local pos = renoise.song().transport.edit_pos
            if mode == 'write' then
              cursor.lane.automation:add_point_at(pos.line, from_fader_device_param(xtouch, nil, cursor.lane.param, cursor.lane.fader_value.value))
              cursor.lane.last_edit_line = pos.line
            elseif mode == 'trim' then
              if cursor.lane.automation.points[pos.line] ~= nil
                    and xtouch.channels[cursor.channel].fader.state.value
                    and cursor.lane.last_edit_line ~= pos.line then
                local val = cursor.lane.fader_value.value - 0.5 + cursor.lane.automation.points[pos.line].value
                val = math.min(1.0, math.max(0, val))
                cursor.lane.automation:add_point_at(pos.line, val)
                cursor.lane.last_edit_line = pos.line
              end
            elseif mode == 'touch' or mode == 'latch' then
              cursor.lane.param.value = from_fader_device_param(xtouch, nil, cursor.lane.param, cursor.lane.fader_value.value)
            end
          end,
        },

        { xtouch = 'cursor.lane.automation and xtouch.channels[cursor.channel].fader or nil,touch',
          callback = function(cursor, state)
            local m = state.automation.mode.value
            if m == 'touch' or m == 'latch' then
              cursor.lane.points = cursor.lane.automation.points
              cursor.lane.automation:clear()
            end
          end,
        },

        { xtouch = 'cursor.lane.automation and xtouch.channels[cursor.channel].fader or nil,release',
          callback = function(cursor, state)
            local m = state.automation.mode.value
            if m == 'touch' or m == 'latch' then
              local p = cursor.lane.points
              cursor.lane.points = nil
              cursor.lane.automation.points = p
            end
            if m == 'trim' then
              cursor.lane.fader_value.value = 0.5
              -- xtouch.channels[cursor.channel].fader.value = 0.5
            elseif m == 'latch' then
              local pos = renoise.song().transport.edit_pos
              cursor.lane.automation:add_point_at(pos.line, cursor.lane.fader_value.value)
            end
          end,
        },

        { renoise = 'cursor.lane.param and cursor.lane.param.value_observable or nil',
          callback = function(cursor, state)
            local touching = xtouch.channels[cursor.channel].fader.state.value
            local mode = state.automation.mode.value
            local fader = cursor.lane.fader_value
            local param = cursor.lane.param

            if not touching then
              if mode == 'trim' then
                fader.value = 0.5
              else
                fader.value = to_fader_device_param(xtouch, nil, param, param.value)
              end
              return
            end

            local pos = renoise.song().transport.edit_pos

            if not cursor.lane.recording.value or cursor.lane.last_edit_line == pos.line then return end

            if mode == 'write' and cursor.lane.automation:has_point_at(pos.line) then
              cursor.lane.automation:remove_point_at(pos.line)
            elseif mode == 'trim'
                  and cursor.lane.automation.points[pos.line] ~= nil
                  and touching
                  and cursor.lane.last_edit_line ~= pos.line then
              local val = cursor.lane.fader_value.value - 0.5 + cursor.lane.automation.points[pos.line].value
              val = math.min(1.0, math.max(0, val))
              cursor.lane.automation:add_point_at(pos.line, val)
              cursor.lane.last_edit_line = pos.line
            elseif mode == 'touch' or mode == 'latch' then
              local v = to_fader_device_param(xtouch, nil, param, param.value)
              if v ~= fader.value then
              end
            end
          end,
        },

        { xtouch = 'cursor.lane.automation and xtouch.channels[cursor.channel].rec or nil,press',
          callback = function(c, s) c.lane.recording.value = not c.lane.recording.value end
        },
        { led = 'xtouch.channels[cursor.channel].rec.led',
          obs = 'cursor.lane.recording',
          value = function(c, s) if c.lane.recording ~= nil then return c.lane.recording.value else return false end end,
          to_led = function(c, s, v) return v and 2 or 0 end
        },

        { xtouch = 'cursor.lane.automation and xtouch.channels[cursor.channel].select or nil,press',
          callback = function(c, s)
            renoise.song().selected_track_index = c.lane.track_index
            renoise.song().selected_automation_parameter = c.lane.param
          end,
        },
        { xtouch = 'cursor.lane.automation and xtouch.channels[cursor.channel].select or nil,release',
          callback = function(c, s)
            renoise.song().selected_automation_parameter = c.lane.param
          end,
        },
        { led = 'xtouch.channels[cursor.channel].select.led',
          obs = 'renoise.song().selected_automation_parameter_observable',
          value = function(c, s) return c.lane.param and rawequal(renoise.song().selected_automation_parameter, c.lane.param) end,
          to_led = function(c, s, v) return v and 2 or 0 end,
        },

        { obs = 'dummy -- strip', scribble = automation_scribble, immediate = true },
        { obs = 'cursor.lane.param and cursor.lane.param.value_observable or nil -- value popup',
          scribble = function(cursor, state)
            local p = cursor.lane.param
            if p == nil then
              return
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
      }
    }
  })
end