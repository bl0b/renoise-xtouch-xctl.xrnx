--[[============================================================================
main.lua
============================================================================]]--

require('lib/xtouch')

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
  _index_floor = 4,
  program_config = renoise.Document.create('XTouchProgramConfig') {},
  show_scribble_gui = 2,
  scribble_gui_brightness = 1,
  scribble_gui_width = 350,
}

local xtouch = nil


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


require 'lib/gui/main_dialog'
function show_dialog() main_dialog(vb, options, xtouch, tool_name) end



function global_init_xtouch()
  -- The ViewBuilder is the basis
  vb = renoise.ViewBuilder()

  if xtouch == nil then
    xpcall(function()
      xtouch = XTouch(options)
      -- then we simply register this document as the main preferences for the tool:
      renoise.tool().preferences = options
      xtouch:config(options)

      if xtouch then
        if options.default_program.value > 0 then
          xtouch:select_program(options.default_program.value)
          -- rprint(xtouch.schema_manager:get_descriptions())
        end
        renoise.tool().app_idle_observable:remove_notifier(global_init_xtouch)
        -- xtouch:init_VU_sends()
        -- show_dialog()

        local show_scribble_gui_callback = function()
          if xtouch.model.value == 'none' then return end
          local xtouch_lacks_scribble_strips = xtouch.model == 'X-Touch Compact' or xtouch.model == 'X-Touch Mini'
          -- print('show', options.show_scribble_gui.value)
          if options.show_scribble_gui.value == 3 then
            scribble_strips_dialog(vb, options, xtouch, tool_name)
          elseif options.show_scribble_gui.value == 2 and xtouch_lacks_scribble_strips then
            scribble_strips_dialog(vb, options, xtouch, tool_name)
          else
            hide_strips_dialog(xtouch)
          end
        end

        xtouch.model:add_notifier(show_scribble_gui_callback)
        options.show_scribble_gui:add_notifier(show_scribble_gui_callback)
        show_scribble_gui_callback()
      else
        -- print('no xtouch', xtouch)
        xtouch = nil
      end
    end, function(err)
      print("[global_init_xtouch]", err)
      print(debug.traceback())
    end)
  end
end

renoise.tool().app_idle_observable:add_notifier(global_init_xtouch)



--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:"..tool_name.."",
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
