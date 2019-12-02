require 'lib/mapping_manager/computed_binding'
require 'lib/mapping_manager'

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


function deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in next, orig, nil do
          copy[deepcopy(orig_key)] = deepcopy(orig_value)
      end
      setmetatable(copy, deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
      copy = orig
  end
  return copy
end


local state_filename = os.currentdir() .. '/XTouchSchemaManager.state'


class "SchemaManager"


function SchemaManager:__init(xtouch, program)
  self.xtouch = xtouch
  self.xtouch.current_page = renoise.Document.ObservableString('none')
  self.mm = MappingManager(xtouch)
  -- print('ctor program', program)
  self:set_program(program)
  renoise.tool().app_new_document_observable:add_notifier(function() self:rebind_to_song() end)
  renoise.tool().app_release_document_observable:add_notifier(function() self:unbind_from_song() end)
end


function SchemaManager:set_program(program)
  -- print('program', program)
  if program == nil then return end
  self.cursor = table.create {}
  self.prog = program

  self.state = self.prog.state

  self.eval_env = {
    delta = 'delta',
    press = 'press',
    release = 'release',
    touch = 'touch',
    move = 'move',
    long_press = 'long_press',
    click = 'click',
    renoise = renoise,
    state = self.prog.state,
    xtouch = self.xtouch,
    cursor = {},
    dummy = renoise.Document.ObservableBang()
  }

  self.compiled_program = self:compile_program(self.prog)
  self:select_page(self.compiled_program.startup_page)
end

local renoise_song = 'renoise.song().'

function SchemaManager:unbind_from_song()
  -- self:clear_assigns()
  -- if self.xtouch.vu_enabled then
  --   self.xtouch:cleanup_LED_support()
  -- end
  self.backup_current_page = self.xtouch.current_page.value
  self:execute_compiled_schema_stack({})
  self.xtouch:init_vu_state()
end


function SchemaManager:rebind_to_song()
  -- self:push_schema(self.current_schema)
  -- if self.xtouch.vu_enabled then
  --   self.xtouch:init_LED_support()
  -- end
  self:select_page(self.backup_current_page)
end


function SchemaManager:lua_eval(str, cursor)
  local ok, reta, retb
  assert(type(str) == 'string', '[xtouch] All bindables must be given as strings (not ' .. type(str) .. ')')
  -- str = str:gsub('(cursor.(%w+))', function(_, name) return self.cursor[name] end)
  local eval_env = table.copy(self.eval_env)
  eval_env.cursor = cursor
  ok, reta, retb = xpcall(
    function()
      return setfenv(assert(loadstring("return " .. str)), eval_env)()
    end,
    function(err)
      print("[xtouch] An error occurred evaluating «" .. str .. "»")
      print(err)
      print(debug.traceback())
      -- print("Eval env:")
      -- rprint(eval_env)
    end)
    if ok then
      return reta, retb
    else
      -- print("[lua_eval]", str, " FAILED")
    end
end



function SchemaManager:copy_cursor()
  local copy = {}
  for k, v in pairs(self.cursor) do
    if string.sub(k, 1, 7) ~= '_frame_' then
      copy[k] = v
      end
  end
  return copy
end



function SchemaManager:eval(v, cursor)
  if v == nil then return end
  if cursor == nil then cursor = self.cursor end
  
  if type(v) == 'function' then
    local status, ret = xpcall(function()
      return v(cursor, self.state)
    end, function(err)
      print("An error occurred while evaluating", v)
      print(err)
      print(debug.traceback())
    end)
    return ret
  end

  return v
end


function SchemaManager:setup_frame(frame, old_values)
  local values = old_values ~= nil and old_values or self:eval(frame.values)
  local channels = self:eval(frame.channels)
  local frame_key = '_frame_' .. frame.name
  local existing_frame = self.cursor[frame_key]
  local start = 1
  if existing_frame then
    start = existing_frame.start
    if start > #values then start = #values - #channels end
    if start < 1 then start = 1 end
  end
  self.cursor[frame_key] = {
    name = frame.name,
    start = start,
    values = values,
    channels = self:eval(frame.channels)
  }
  return self.cursor['_frame_' .. frame.name]
end


function dump_state(state, ...)
  local path = {...}
  for i = 1, #path do
    state = state and state[path[i]]
  end
  print(table.concat(path, '.'), state)
end

function SchemaManager:select_page(page_name)
  -- print('[xtouch] select_page «' .. page_name .. '»')
  local page = self.compiled_program.pages[page_name]
  if page ~= nil then
    self:execute_compiled_schema_stack(page.schemas)
    self.xtouch.current_page.value = page_name
  else
    error("nil page requested")
  end
end

function SchemaManager:refresh()
  self:select_page(self.xtouch.current_page.value)
end



require 'lib/schema_manager/compile'
require 'lib/schema_manager/describe'