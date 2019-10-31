local automation_cursor = renoise.Document.ObservableNumber(1)

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


function lane_key(ti, d, p)
  return string.format('%d/%s/%s', ti, d.display_name, p.name)
end

local current_xtouch_lanes = {}
local old_cursor_start = 0




function automation_frame(xtouch, state)
  local dummy = renoise.Document.ObservableBang()
  local current_lanes = {}
  return with_menu_mappings(xtouch, {
    assign = {
      { xtouch = 'xtouch.channel.left,press',
        callback = function(c, s) s.automation.cursor.value = s.automation.cursor.value - 1 end,
        description = 'Move frame left',
      },
      { xtouch = 'xtouch.channel.right,press',
        callback = function(c, s) s.automation.cursor.value = s.automation.cursor.value + 1 end,
        description = 'Move frame right',
      },
      { xtouch = 'xtouch.bank.left,press',
        callback = function(c, s) s.automation.cursor.value = s.automation.cursor.value - 8 end,
        description = 'Move frame left by 8 lanes',
      },
      { xtouch = 'xtouch.bank.right,press',
        callback = function(c, s) s.automation.cursor.value = s.automation.cursor.value + 8 end,
        description = 'Move frame right by 8 lanes',
      },

      { renoise = 'state.automation.cursor', frame = 'update' },
      { renoise = 'renoise.song().selected_pattern_observable -- update', frame = 'update' },
      { renoise = 'renoise.song().selected_pattern_track_observable -- update', frame = 'update' },
      { renoise = 'state.automation.all_tracks -- update', frame = 'update' },
      { renoise = 'renoise.song().selected_sequence_index_observable', frame='update' },

      { xtouch = 'xtouch.automation.read_off,press',
        callback = function(cursor, state) state.automation.mode.value = 'read' end,
        description = 'READ-ONLY mode\nDisable fader input.'
      },
      { xtouch = 'xtouch.automation.write,press',
        callback = function(cursor, state) state.automation.mode.value = 'write' end,
        description = 'WRITE mode\nFader overwrites automation.'
      },
      { xtouch = 'xtouch.automation.trim,press',
        callback = function(cursor, state)
          state.automation.mode.value = 'trim'
          for i = 1, 8 do
            local lane = current_xtouch_lanes[i]
            if lane and lane.fader_value then
              lane.fader_value.value = 0.5
            end
          end
        end,
        description = 'TRIM mode\nFader trims automation.'
      },
      { xtouch = 'xtouch.automation.touch,press',
        callback = function(cursor, state) state.automation.mode.value = 'touch' end,
        description = "TOUCH mode\nFader changes parameter\nbut doesn't alter automation",
      },
      { xtouch = 'xtouch.automation.latch,press',
        callback = function(cursor, state) state.automation.mode.value = 'latch' end,
        description = "LATCH mode\nFader changes parameter\nFader release writes last\nvalue to automation",
      },
      { xtouch = 'xtouch.automation.group,press',
        callback = function(cursor, state) state.automation.all_tracks.value = not state.automation.all_tracks.value end,
        description = 'View all tracks or single track.'
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
    },

    frame = {
      name = 'lane',
      channels = {1, 2, 3, 4, 5, 6, 7, 8},

      before = function()
        renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
      end,

      values = function(cursor, state)
        local current_automations, automation_tracks, slots, s = {}, {}, {}, renoise.song()

        local automations_in_track = function(ti)
          for ai = 1, #s.selected_pattern.tracks[ti].automation do
            local li, a = #current_automations + 1, s.selected_pattern.tracks[ti].automation[ai]
            current_automations[li] = a
            current_automations[lane_key(ti, a.dest_device, a.dest_parameter)] = li
            automation_tracks[li] = ti
          end
        end

        -- get current automation lanes
        if state.automation.all_tracks.value then
          for ti = 1, #s.tracks do automations_in_track(ti) end
        else
          automations_in_track(s.selected_track_index)
        end

        for i = 1, 8 do
          local lane = current_xtouch_lanes[i]
          if lane == nil then
            slots[#slots + 1] = i
          elseif lane.recording ~= nil and lane.recording.value then
            local key = lane_key(lane.track_index, lane.device, lane.param)
            local new_automation = current_automations[key] and current_automations[current_automations[key]]
            if new_automation == nil then
              local pt = renoise.song().selected_pattern:track(lane.track_index)
              new_automation = pt:find_automation(lane.param) or pt:create_automation(lane.param)
            end
            if lane.terminate and not rawequal(lane.automation, new_automation) then lane.terminate() end
            lane.automation = new_automation
            if xtouch.channels[i].fader.state.value and (state.automation.mode.value == 'touch' or state.automation.mode.value == 'latch') then
              lane.points = lane.automation.points
              lane.automation:clear()
            end
            current_automations[key] = nil
          else
            slots[#slots + 1] = i
          end
        end

        local cak = function(i)
          local ca = current_automations[i]
          return ca and lane_key(automation_tracks[i], ca.dest_device, ca.dest_parameter)
        end

        local available_automations, avail_tracks = {}, {}
        for i = 1, #current_automations do
          if current_automations[cak(i)] ~= nil then
            available_automations[#available_automations + 1] = current_automations[i]
            avail_tracks[#avail_tracks + 1] = automation_tracks[i]
          end
        end

        local max = #available_automations + 2 - #slots
        if state.automation.cursor.value > max then state.automation.cursor.value = max end
        if state.automation.cursor.value < 1 then state.automation.cursor.value = 1 end

        local cai = state.automation.cursor.value

        for si, sloti in ipairs(slots) do
          local auto = available_automations[cai]
          current_xtouch_lanes[sloti] = auto ~= nil and lane(xtouch, auto, avail_tracks[cai]) or lane(xtouch)
          cai = cai + 1
        end

        return current_xtouch_lanes
      end,

      assign = {
        { fader = 'cursor.lane.automation and xtouch.channels[cursor.channel].fader or nil',
          obs = 'cursor.lane.param and cursor.lane.fader_value',
          value = 'cursor.lane.param and cursor.lane.fader_value',
          to_fader = function(cursor, state, value) return value end,
          from_fader = function(cursor, state, value) return value end,
          description = 'Trim amount or Parameter value',
        },

        { renoise = 'cursor.lane.automation and cursor.lane.fader_value or nil',
          callback = function(cursor, state)
            if not xtouch.channels[cursor.channel].fader.state.value then return end
            local mode = state.automation.mode.value
            if mode == 'read' or not cursor.lane.recording.value then return end
            local pos = renoise.song().transport.edit_pos
            if mode == 'write' then
              local p = cursor.lane.param
              local v = from_fader_device_param(xtouch, nil, p, cursor.lane.fader_value.value)
              v = (v - p.value_min) / (p.value_max - p.value_min)
              cursor.lane.automation:add_point_at(pos.line, v)
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
          description = 'Begin editing automation',
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
          description = 'Finish editing automation',
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
          callback = function(c, s) c.lane.recording.value = not c.lane.recording.value end,
          description = 'Toggle edit mode for this lane',
        },
        { led = 'xtouch.channels[cursor.channel].rec.led',
          obs = 'cursor.lane.recording',
          value = function(c, s) if c.lane.recording ~= nil then return c.lane.recording.value else return false end end,
          to_led = function(c, s, v) return v and 2 or 0 end
        },

        { xtouch = 'cursor.lane.automation and xtouch.channels[cursor.channel].select or nil,press',
          callback = function(c, s)
            renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
            renoise.song().selected_track_index = c.lane.track_index
            renoise.song().selected_automation_parameter = c.lane.param
          end,
          description = 'Display automation data',
        },
        -- { xtouch = 'cursor.lane.automation and xtouch.channels[cursor.channel].select or nil,release',
        --   callback = function(c, s)
        --     renoise.song().selected_automation_parameter = c.lane.param
        --   end,
        -- },
        { led = 'xtouch.channels[cursor.channel].select.led',
          obs = 'renoise.song().selected_automation_parameter_observable',
          value = function(c, s) return c.lane.param and rawequal(renoise.song().selected_automation_parameter, c.lane.param) end,
          to_led = function(c, s, v) return v and 2 or 0 end,
        },
        { led = 'xtouch.channels[cursor.channel].solo.led', obs = 'dummy -- solo LED off', value = function(c, s) end, to_led = function(c, s, v) return 0 end, immediate = true },
        { led = 'xtouch.channels[cursor.channel].mute.led', obs = 'dummy -- mute LED off', value = function(c, s) end, to_led = function(c, s, v) return 0 end, immediate = true },

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