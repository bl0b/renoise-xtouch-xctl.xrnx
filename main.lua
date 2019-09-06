--[[============================================================================
main.lua
============================================================================]]--

require('lib/xtouch')

-- Placeholder for the dialog
local dialog = nil
local bindings_dialog = nil

-- Placeholder to expose the ViewBuilder outside the show_dialog() function
local vb = nil

-- Read from the manifest.xml file.
class "RenoiseScriptingTool" (renoise.Document.DocumentNode)
  function RenoiseScriptingTool:__init()    
    renoise.Document.DocumentNode.__init(self) 
    self:add_property("Name", "X-Touch XCtl")
    self:add_property("Id", "Unknown Id")
  end

local manifest = RenoiseScriptingTool()
local ok,err = manifest:load_from("manifest.xml")
local tool_name = manifest:property("Name").value
local tool_id = manifest:property("Id").value


-- tools can have preferences, just like Renoise. To use them we first need 
-- to create a renoise.Document object which holds the options that we want to 
-- store/restore
local options = renoise.Document.create("XTouchPreferences") {
  input_device = '',
  output_device = '',
  ping_period = 1000,
  long_press_ms = 1500,
  default_program = 1,
  vu_ceiling = 0,
  vu_floor = -42,
  vu_range = 42,
  _index_in = 0,
  _index_out = 0,
  _index_ceil = 1,
  _index_floor = 4
}

local xtouch = nil

local vu_ceiling_items = {
  '0 dB',
  '-3 dB',
  '-6 dB',
  '-12 dB',
  '-18 dB',
}

local vu_ceiling_values = { 0, -3, -6, -12, -18 }

local vu_range_items = {
  '7 dB',
  '14 dB',
  '21 dB',
  '42 dB',
  '63 dB'
}

local vu_range_values = { 7, 14, 21, 42, 63 }

-- then we simply register this document as the main preferences for the tool:
renoise.tool().preferences = options


-- Reload the script whenever this file is saved. 
-- Additionally, execute the attached function.
_AUTO_RELOAD_DEBUG = function()
  print('Reloaded X-Touch tool.')
  if xtouch == nil then return end
  if xtouch.schema_manager ~= nil then
    xtouch.schema_manager:unbind_from_song()
  end
  xtouch:close()
  xtouch = XTouch(options)
end

--------------------------------------------------------------------------------
-- Main functions
--------------------------------------------------------------------------------

-- ...

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------



function add_binding(name, event, descr, container)
  container:add_child(vb:row {
    vb:textfield {
      text = event,
      width = 60,
      active = false,
      align = 'center'
    },
    vb:space { width = 2, },
    vb:text {
      text = name,
      width = 90,
      style = 'strong'
    },
    vb:space { width = 2, },
    vb:text {
      text = descr,
      width = 160,
      style = descr == 'UNDOCUMENTED' and 'disabled' or 'normal'
    }
  })
end

function create_group(name)
  return vb:column {
    style = 'group',
    margin = 2,
    spacing = 2,
    vb:row {
      style = 'border',
      margin = 3,
      vb:text {
        style = 'strong',
        text = name,
        width = 210,
        align = 'center'
      }
    }
  }
end

function show_bindings(program_number)
  -- This block makes sure a non-modal dialog is shown once.
  -- If the dialog is already opened, it will be focused.
  if bindings_dialog and bindings_dialog.visible then
    bindings_dialog:show()
    return
  end

  print('PROUT', program_number)
  print(xtouch)
  print(xtouch.programs)
  local program = xtouch.programs[program_number]
  rprint(program)
  
  local schemas = xtouch.schema_manager:get_descriptions(program)
  local content = vb:row { spacing = 10, margin = 10 }
  for name, bindings in pairs(schemas) do
    name = name:gsub('_', ' ')
    name = name:sub(1, 1):upper() .. name:sub(2)
    local col = vb:column {
      -- spacing = 5,
      -- width = 420,
      style = 'panel',
      spacing = 5,
      margin = 5,
      vb:text {
        text = name:upper(),
        width = '100%',
        align = 'center',
        style = 'strong'
      }
    }
    local bindlist = vb:column {
      spacing = 5
    }
    local ungrouped = create_group('(ungrouped)')
    col:add_child(bindlist)
    local have_ungrouped = false
    for k, v in pairs(bindings.assign) do
      if v.leaf then
        have_ungrouped = true
        print('--', #v)
        rprint(v)
        print('--')
        for i = 1, #v do
          add_binding(k, v[i].event, v[i].descr, ungrouped)
        end
      -- add_binding(k, v.event, v.descr, ungrouped)
      end
    end
    if have_ungrouped then bindlist:add_child(ungrouped) end
    for k, v in pairs(bindings.assign) do
      if not v.leaf then -- Group
        local grp = create_group(k)
        for l, u in pairs(v) do
          for k = 1, #u do
            add_binding(l, u[k].event, u[k].descr, grp)
          end
        end
        bindlist:add_child(grp)
      end
    end
    for k, v in pairs(bindings.frame) do
      if not v.leaf then -- Group
        local grp = create_group(k)
        for l, u in pairs(v) do
          for k = 1, #u do
            add_binding(l, u[k].event, u[k].descr, grp)
          end
        end
        bindlist:add_child(grp)
      else
        add_binding(k, v.event, v.descr, bindlist)
      end
    end
    content:add_child(col)
  end

  bindings_dialog = renoise.app():show_custom_dialog(tool_name .. ' | Bindings for program «' .. xtouch.schema_manager.prog.name .. '»', content)
end





local function show_dialog()

  -- This block makes sure a non-modal dialog is shown once.
  -- If the dialog is already opened, it will be focused.
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  -- The ViewBuilder is the basis
  vb = renoise.ViewBuilder()

  local label_width = 130
  local form_label = function(txt)
    return vb:row {
      vb:text { text = txt, width = label_width, align = 'right' },
      vb:space { width = 10 }
    }
  end

  local reset_xtouch = function()
    local have_sm = xtouch.schema_manager ~= nil
    if have_sm then xtouch.schema_manager:unbind_from_song() end
    xtouch:close()
    xtouch:config(options)
    xtouch:open()
    if options.default_program.value > 0 then
      xtouch:select_program(options.default_program.value)
    end
  end

  -- The content of the dialog, built with the ViewBuilder.
  local content = vb:column {
    margin = 5,
    -- vb:column {
    --   width = '100%',
    --   vb:text {
    --     text = "X-Touch [XCtl]",
    --     font = 'big',
    --     align = 'center',
    --     width = '100%'
    --   },
    --   vb:text {
    --     text = 'by bl0b',
    --     font = 'italic',
    --     align = 'center',
    --     width = '100%'
    --   },
    --   vb:space { height = 10 }
    -- },
    vb:column {
      margin = 10,
      style = 'panel',
      width = 420,
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
              print('midi in', value)
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
              print('midi out', value)
              -- rprint(renoise.Midi.available_output_devices())
              options.output_device.value = renoise.Midi.available_output_devices()[value]
              -- reset_xtouch()
            end,
            tooltip = 'Select the port to which the X-Touch is connected'
          },
          tooltip = 'Select the port to which the X-Touch is connected'
        },
        vb:row {
          form_label("Connection status"),
          vb:checkbox { bind = xtouch.is_alive, active = false },
          vb:space { width = 20 },
          vb:button {
            text = 'RESET',
            notifier = reset_xtouch
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
              print('VU ceiling', value)
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
              print('VU range', value)
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
        style = 'group',
        width = '100%',
        margin = 5,
        vb:text {
          text = "Available programs",
          font = "bold",
          width = "100%",
          align = "center"
        },
        vb:column {
          width = '100%',
          id = 'programs'
        },
        vb:multiline_textfield {
          width = '100%',
          active = false,
          text = (function()
            local p = table.create {}
            for i = 1, #xtouch.programs do
              p[i] = '#' .. i .. ': ' .. xtouch.programs[i].name
            end
            return p:concat('\n')
          end)()
        }
      }
    }
  }

  for i = 1, #xtouch.programs do
    vb.views.programs:add_child(vb:row {
      spacing = 10,
      style = 'panel',
      vb:text {
        text = '#' .. i,
        style='strong'
      },
      vb:row {
        vb:text {
          text = xtouch.programs[i].name,
          style='strong'
        },
      },
      vb:button {
        text = '?',
        notifier = function() show_bindings(i) end
      }
    })
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




function global_init_xtouch()
  if xtouch == nil then
    xpcall(function()
      xtouch = XTouch(options)
      if xtouch then
        if options.default_program.value > 0 then
          xtouch:select_program(options.default_program.value)
          -- rprint(xtouch.schema_manager:get_descriptions())
        end
        renoise.tool().app_idle_observable:remove_notifier(global_init_xtouch)
        -- xtouch:init_VU_sends()
        show_dialog()
      else
        -- print('no xtouch', xtouch)
        xtouch = nil
      end
    end, function(err)
      print("[global_init_xtouch]")
      print(err)
      print(debug.traceback())
    end)
  end
end

renoise.tool().app_idle_observable:add_notifier(global_init_xtouch)
-- renoise.tool().app_idle_observable:add_notifier(show_dialog())
-- global_init_xtouch()



--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:"..tool_name.."...",
  invoke = show_dialog  
}


--------------------------------------------------------------------------------
-- Key Binding
--------------------------------------------------------------------------------

--[[
renoise.tool():add_keybinding {
  name = "Global:Tools:" .. tool_name.."...",
  invoke = show_dialog
}
--]]


--------------------------------------------------------------------------------
-- MIDI Mapping
--------------------------------------------------------------------------------

--[[
renoise.tool():add_midi_mapping {
  name = tool_id..":Show Dialog...",
  invoke = show_dialog
}
--]]
