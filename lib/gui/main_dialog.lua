require 'lib/gui/show_bindings'

local dialog = nil

local content_width = 378

local vu_ceiling_items = {
  '0 dB',
  '-3 dB',
  '-6 dB',
  '-12 dB',
  '-18 dB',
}

_AUTO_RELOAD_DEBUG = function() end


local vu_ceiling_values = { 0, -3, -6, -12, -18 }

local vu_range_items = {
  '7 dB',
  '14 dB',
  '21 dB',
  '42 dB',
  '63 dB'
}

local vu_range_values = { 7, 14, 21, 42, 63 }


function update_xtouch(xtouch, program)
  print('refresh', type(xtouch), xtouch, type(program), program)
  if xtouch._program_number.value == program.number then
    xtouch.schema_manager:refresh()
  end
end


function program_card(vb, content, options, xtouch, tool_name, program)
  local gui_width = 339
  local widget_width = 170
  local label_width = gui_width - widget_width - 23
  local config_gui = vb:column {margin = 5, spacing = 0, width = gui_width, visible = false, style = 'body'}

  if program.config and program.config_meta then
    for name, meta in pairs(program.config_meta) do
      local label_gui = vb:row {
        vb:text { text = meta.label, width = label_width, align = 'right', tooltip = meta.tooltip },
        vb:space { width = 10 }
      }
      local row = vb:row { margin = 0, label_gui, style = 'group' }
      local obs = options.program_config[program.name][name]
      local t = type(obs)
      print(t)
      local update = function() if meta.callback then meta.callback() end update_xtouch(xtouch, program) end
      if t == 'ObservableBoolean' then
        if meta.switch then
          row:add_child(vb:switch {
            items = meta.switch.items, width = widget_width, value = table.find(meta.switch.values, obs.value),
            notifier = function(value)
              obs.value = meta.switch.values[value]
              update()
            end,
            tooltip = meta.tooltip
          })
        else
          local cb = vb:checkbox { bind = obs, tooltip = meta.tooltip, notifier = update }
          row:add_child(cb)
          row:add_child(vb:space { width = widget_width - cb.width })
        end
      elseif t == 'ObservableNumber' then
        row:add_child(vb:slider {
          min = meta.min, max = meta.max,
          bind = obs,
          tooltip = meta.tooltip,
          width = widget_width - 30,
          notifier = update
        })
        row:add_child(vb:valuefield { bind = obs, min = meta.min, max = meta.max, tooltip = meta.tooltip, width = 30, notifier = update })
      elseif t == 'ObservableString' then
        row:add_child(vb:textfield {
          width = widget_width,
          bind = obs,
          notifier = update
        })
      else
        print('[xtouch] unhandled type in program config', t)
      end
      config_gui:add_child(row)
      config_gui:add_child(vb:space { height = 5 })
    end
  end

  return vb:column {
    style = 'group',
    margin = 2,
    vb:column {
      style = 'border',
      margin = 0,
      width = 339,
      vb:row {
        vb:space { height = 5 },
        vb:column {
          width = 20,
          vb:space { height = 5 },
          vb:text {
            width = 20,
            -- style = 'normal',
            font = 'mono',
            text = ' ' .. program.number
          },
        },
        vb:space { width = 5 },
        vb:column {
          width = 260,
          vb:space { height = 5 },
          vb:text {
            width = 260,
            align = 'center',
            text = program.name,
            style = 'normal',
            font = 'bold'
          },
        },
        vb:space { width = 5 },
        vb:column {
          width = 44,
          vb:space { height = 5 },
          vb:row {
            vb:button {
              text = '⚙',
              tooltip = 'Show/Hide configuration settings',
              notifier = function()
                config_gui.visible = not config_gui.visible
                content.width = content_width - 10
              end,
              active = program.config and program.config_meta and true or false
            },
            vb:space { height = 5 },
            vb:button {
              text = '?',
              tooltip = 'Show the bindings in a new window',
              notifier = function() show_bindings_dialog(vb, xtouch, tool_name, program) end
            },
              },
        }
      },
      vb:space { height = 5 },
      config_gui,
      vb:row {
        style = 'body',
        vb:space { width = 3 },
        vb:multiline_text {
          width = 335,
          style = 'body',
          height = 40,
          font = 'italic',
          text = program.description
        }
      }
    }
  }
end


function main_dialog(vb, options, xtouch, tool_name)

  -- This block makes sure a non-modal dialog is shown once.
  -- If the dialog is already opened, it will be focused.
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  local label_width = 130
  local form_label = function(txt)
    return vb:row {
      vb:text { text = txt, width = label_width, align = 'right' },
      vb:space { width = 10 }
    }
  end

  local reset_xtouch = function()
    local have_sm = xtouch.schema_manager ~= nil
    -- if have_sm then xtouch.schema_manager:unbind_from_song() end
    xtouch:close()
    xtouch:config(options)
    xtouch:open()
    -- if options.default_program.value > 0 then
    -- xtouch:select_program(options.default_program.value)
    if have_sm then xtouch.schema_manager:refresh() end
    -- end
  end


  -- The content of the dialog, built with the ViewBuilder.
  local content = vb:column {
    margin = 5,
    style = 'panel',
    width = content_width,
    vb:column {
      style = 'group',
      width = '100%',
      margin = 5,
      vb:row {
        form_label("MIDI In"),
        vb:popup {
          items = renoise.Midi.available_input_devices(),
          value = table.find(renoise.Midi.available_input_devices(), options.input_device),
          bind = options._index_in,
          width = 200,
          notifier = function(value)
            -- print('midi in', value)
            -- rprint(renoise.Midi.available_input_devices())
            options.input_device.value = renoise.Midi.available_input_devices()[value]
            -- reset_xtouch()
          end,
          tooltip = 'Select the port to which the X-Touch is connected'
        },
        tooltip = 'Select the port to which the X-Touch is connected'
      },
      vb:space { height = 5 },
      vb:row {
        form_label("MIDI Out"),
        vb:popup {
          items = renoise.Midi.available_output_devices(),
          value = table.find(renoise.Midi.available_output_devices(), options.output_device),
          bind = options._index_out,
          width = 200,
          notifier = function(value)
            -- print('midi out', value)
            -- rprint(renoise.Midi.available_output_devices())
            options.output_device.value = renoise.Midi.available_output_devices()[value]
            -- reset_xtouch()
          end,
          tooltip = 'Select the port to which the X-Touch is connected'
        },
        tooltip = 'Select the port to which the X-Touch is connected'
      },
      vb:space { height = 5 },
      vb:row {
        form_label("Connected model"),
        -- vb:checkbox { bind = xtouch.is_alive, active = false },
        vb:textfield { bind = xtouch.model, active = false, width = 120, tooltip = 'If an X-Touch is connected, its model name appears here.' },
        vb:space { width = 20 },
        vb:button {
          width = 60,
          text = 'RESET',
          notifier = reset_xtouch,
          tooltip = 'Reset the MIDI connection'
        }
      }
    },
    vb:space { height = 10 },
    vb:column {
      style = 'group',
      width = '100%',
      margin = 5,
      vb:row {
        form_label("Long press duration (ms)"),
        vb:slider { min = 50, max = 2500, bind = options.long_press_ms, tooltip = 'Time in milliseconds to wait before detecting a long press', width = 160 },
        vb:valuefield { bind = options.long_press_ms, tooltip = 'Time in milliseconds to wait before detecting a long press', width = 40 },
        tooltip = 'Time in milliseconds to wait before detecting a long press'
      },
    },
    vb:space { height = 10 },
    vb:column {
      style = 'group',
      width = '100%',
      margin = 5,
      vb:row {
        form_label("VU ceiling"),
        vb:switch {
          items = vu_ceiling_items,
          width = 200,
          bind = options._index_ceil,
          notifier = function(value)
            -- print('VU ceiling', value)
            xtouch:set_vu_range(vu_ceiling_values[options._index_ceil.value],
                                vu_range_values[options._index_floor.value])
            options.vu_ceiling.value = xtouch.vu_ceiling
          end
        },
        tooltip = 'Signal above this level will turn on the clip LED'
      },
      vb:space { height = 10 },
      vb:row {
        form_label("VU range"),
        vb:switch {
          items = vu_range_items,
          width = 200,
          bind = options._index_floor,
          notifier = function(value)
            -- print('VU range', value)
            xtouch:set_vu_range(vu_ceiling_values[options._index_ceil.value],
                                vu_range_values[options._index_floor.value])
            options.vu_floor.value = xtouch.vu_floor
            options.vu_range.value = xtouch.vu_range
          end
        }
      }
    },
    vb:space { height = 10 },
    vb:column {
      width = '100%',
      vb:row {
        style = 'group',
        vb:text {
          text = "Available programs",
          font = "bold",
          width = 353,
          align = "center"
        },
      },
      vb:space { height = 5 },
      vb:column {
        margin = 5,
        spacing = 5,
        width = '100%',
        id = 'programs',
      }
    }
  }

  -- vb.views.programs:add_child(program_card(vb, content, options, xtouch, tool_name, {
  --   name = 'Program Selector',
  --   number = '',
  --   description = "Bindings to switch between programs. Always present.\nThis is not a program you can switch to.",
  --   schemas = {
  --     _ = function() return {
  --       assign = {
  --         { xtouch = 'xtouch.transport.jog_wheel,delta', description = 'Select program' },
  --         { xtouch = 'xtouch.display,long_press', description = 'Toggle program selection' }
  --       }
  --     } end,
  --   },
  --   pages = { ProgramSelector = { description = "Switch between programs. These bindings are always present.", schemas = {'_'} } },
  --   startup_page = 'ProgramSelector'
  -- }))

  for i = 1, #xtouch.programs do
    vb.views.programs:add_child(program_card(vb, content, options, xtouch, tool_name, xtouch.programs[i]))
  end

  -- A custom dialog is non-modal and displays a user designed
  -- layout built with the ViewBuilder.   
  dialog = renoise.app():show_custom_dialog(tool_name, content)

  -- A custom prompt is a modal dialog, restricting interaction to itself. 
  -- As long as the prompt is displayed, the GUI thread is paused. Since 
  -- currently all scripts run in the GUI thread, any processes that were running 
  -- in scripts will be paused. 
  -- A custom prompt requires buttons. The prompt will return the label of 
  -- the button that was pressed or nil if the dialog was closed with the 
  -- standard X button.  
  --[[ 
    local buttons = {"OK", "Cancel"}
    local choice = renoise.app():show_custom_prompt(
      tool_name, 
      content, 
      buttons
    )  
    if (choice == buttons[1]) then
      -- user pressed OK, do something  
    end
    xtouch:close()
    xtouch = nil
  --]]
end