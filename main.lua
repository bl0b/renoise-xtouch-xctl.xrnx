--[[============================================================================
main.lua
============================================================================]]--

require('lib/xtouch')

-- Placeholder for the dialog
local dialog = nil

-- Placeholder to expose the ViewBuilder outside the show_dialog() function
local vb = nil

local xtouch = nil

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
  input_device = 'Focusrite USB MIDI',
  output_device = 'Focusrite USB MIDI',
  ping_period = 1000,
  long_press_ms = 1500,
  default_program = 1,
  vu_ceiling = 0,
  vu_floor = -42,
  _index_in = 0,
  _index_out = 0,
  _index_ceil = 1,
  _index_floor = 4
}

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
  if xtouch then xtouch:close() end
  print("long_press_ms", options.long_press_ms)
  xtouch = nil
  -- xtouch = XTouch(options.input_device.value, options.output_device.value, options.ping_period.value, options.long_press_ms)
end

--------------------------------------------------------------------------------
-- Main functions
--------------------------------------------------------------------------------

-- ...

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

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

  local reset_xtouch = function() xtouch:reset() end

  -- The content of the dialog, built with the ViewBuilder.
  local content = vb:column {
    -- margin = 10,
    vb:column {
      -- margin = 10,
      width = '100%',
      vb:text {
        text = "X-Touch [XCtl]",
        font = 'big',
        align = 'center',
        width = '100%'
      },
      vb:text {
        text = 'by bl0b',
        font = 'italic',
        align = 'center',
        width = '100%'
      }
    },
    vb:column {
      margin = 5,
      style = 'panel',
      width = 400,
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
              options.input_device = value
              reset_xtouch()
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
              options.output_device = value
              reset_xtouch()
            end,
            tooltip = 'Select the port to which the X-Touch is connected'
          },
          tooltip = 'Select the port to which the X-Touch is connected'
        },
        vb:row {
          form_label("Connection status"),
          vb:checkbox { bind = xtouch.is_alive },
          vb:space { width = 20 },
          vb:button {
            text = 'RESET',
            notifier = reset_xtouch
          }
        }
      },
      vb:space { height = 5 },
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
        vb:row {
          form_label("Ping period (ms)"),
          vb:slider { min = 500, max = 5000, bind = options.ping_period, width = 160, tooltip = 'Ping period in milliseconds. Too low it will bloat the MIDI device. Too high and the X-Touch will disconnect and lose current state.' },
          vb:valuefield { bind = options.ping_period, width = 40, tooltip = 'Ping period in milliseconds. Too low it will bloat the MIDI device. Too high and the X-Touch will disconnect and lose current state.' },
          tooltip = 'Ping period in milliseconds. Too low it will bloat the MIDI device. Too high and the X-Touch will disconnect and lose current state.'
        },
      },
      vb:space { height = 5 },
      vb:column {
        style = 'group',
        width = '100%',
        margin = 5,
        vb:row {
          form_label("VU ceiling"),
          vb:switch { items = vu_ceiling_items, value = 1, width = 200, bind = options._index_ceil },
          tooltip = 'Signal above this level will turn on the clip LED'
        },
        vb:space { height = 5 },
        vb:row {
          form_label("VU range"),
          vb:switch { items = vu_range_items, value = 1, width = 200, bind = options._index_floor }
        }
        }
    }
  }

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

-- pcall = function(x) return true, x() end

function global_init_xtouch()
  if xtouch == nil then
    xpcall(function()
      xtouch = XTouch(options)
      if xtouch then
        if options.default_program.value > 0 then
          xtouch:select_program(options.default_program.value)
        end
        renoise.tool().app_idle_observable:remove_notifier(global_init_xtouch)
        -- xtouch:init_VU_sends()
      else
        -- print('no xtouch', xtouch)
        xtouch = nil
      end
    end, function(err)
      print(err)
      print(debug.traceback())
    end)
  end
end

renoise.tool().app_idle_observable:add_notifier(global_init_xtouch)
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
