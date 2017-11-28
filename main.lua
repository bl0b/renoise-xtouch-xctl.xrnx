--[[============================================================================
main.lua
============================================================================]]--

require('lib/xtouch')

-- Placeholder for the dialog
local dialog = nil

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
  input_device = 'Focusrite USB MIDI',
  output_device = 'Focusrite USB MIDI',
  ping_period = 1000,
  long_press_ms = 1500,
  default_program = 1
}

-- then we simply register this document as the main preferences for the tool:
renoise.tool().preferences = options


local xtouch = XTouch(options)
if options.default_program.value > 0 then
  xtouch:select_program(options.default_program.value)
end


-- Reload the script whenever this file is saved. 
-- Additionally, execute the attached function.
_AUTO_RELOAD_DEBUG = function()
  print('Reloaded X-Touch tool.')
  xtouch:close()
  print("long_press_ms", options.long_press_ms)
  xtouch = XTouch(options.input_device.value, options.output_device.value, options.ping_period.value, options.long_press_ms)
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

  -- The content of the dialog, built with the ViewBuilder.
  local content = vb:column {
    margin = 10,
    vb:text {
      text = "X-Touch XCtl support by bl0b"
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
