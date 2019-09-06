require 'lib/computed_binding'
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


class "SchemaManager" (renoise.Document.DocumentNode)


function SchemaManager:__init(xtouch, program)
  self.mm = MappingManager(xtouch)
  self.cursor = table.create {}
  self.xtouch = xtouch
  self.prog = program

  self.state = program.state

  self.eval_env = {
    delta = 'delta',
    press = 'press',
    release = 'release',
    touch = 'touch',
    move = 'move',
    renoise = renoise,
    state = program.state,
    xtouch = xtouch
  }
  
  self.compiled_program = self:compile_program(program)

  self:execute_compiled_schema_stack(self.compiled_program.startup)
end

local renoise_song = 'renoise.song().'

function SchemaManager:unbind_from_song()
  -- self:clear_assigns()
  -- if self.xtouch.vu_enabled then
  --   self.xtouch:cleanup_LED_support()
  -- end
end


function SchemaManager:rebind_to_song()
  -- self:push_schema(self.current_schema)
  -- if self.xtouch.vu_enabled then
  --   self.xtouch:init_LED_support()
  -- end
end


function SchemaManager:lua_eval(str)
  local ok, reta, retb
  assert(type(str) == 'string', 'All bindables must be given as strings')
  str = str:gsub('(cursor.(%w+))', function(_, name) return self.cursor[name] end)
  ok, reta, retb = xpcall(
    function()
      return setfenv(assert(loadstring("return " .. str)), self.eval_env)()
    end,
    function(err)
      print("An error occurred evaluating «" .. str .. "»")
      print(err)
      print(debug.traceback())
    end)
    if ok then
      if str:sub(1, 6) == 'state.' then print("[lua_eval]", str, "OK", type(reta), reta, type(retb), retb) end
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


function SchemaManager:setup_frame(frame)
  local values = self:eval(frame.values)
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
    values = self:eval(frame.values),
    channels = self:eval(frame.channels)

  }
  return self.cursor['_frame_' .. frame.name]
end




function condense_sequence(tab)
  local buckets = {{1, 1}}
  for i = 2, #tab do
    if tab[i] == tab[buckets[#buckets][2]] + 1 then
      buckets[#buckets][2] = i
    else
      buckets[#buckets + 1] = {i, i}
    end
  end
  for i = 1, #buckets do
    local b = buckets[i]
    if b[1] == b[2] then
      buckets[i] = '#' .. tab[b[1]]
    else
      buckets[i] = '#' .. tab[b[1]] .. '-#' .. tab[b[2]]
    end
  end
  return table.concat(buckets, ', ')
end


function description_key(source, frame_channels)
  source = source:gsub('xtouch.', '')
  if frame_channels then
    source = source:gsub('channels[[]].', 'Tracks ' .. frame_channels .. '/')  -- only happens within frame assigns
  end
  source = source:gsub('channels[[](%d)[]].', 'Track #%1/')  -- only happens within frame assigns
  source = source:gsub('channels.main.', 'Main Track/')  -- only happens within frame assigns
  source = source:gsub('_', ' ')
  source = source:upper()
  local split_event = source:gmatch('[^,]+')
  local path, event = split_event(), split_event()
  local split_path = path:gmatch('[^./]+')
  local deep_path = table.create {}
  for i in split_path do
    deep_path[1 + #deep_path] = '' .. i
  end
  return deep_path, event
end


function create_path(dest_table, deep_path, i, event, descr)
  if #deep_path == i then
    if dest_table[deep_path[i]] == nil then
      dest_table[deep_path[i]] = table.create { leaf = true }
    end
    local t = dest_table[deep_path[i]]
    t[#t + 1] = {event=event, descr=descr}
    return
  end
  if dest_table[deep_path[i]] == nil then
    dest_table[deep_path[i]] = table.create {}
  end
  create_path(dest_table[deep_path[i]], deep_path, i + 1, event, descr)
end


function SchemaManager:analyze_binding(cursor, binding, dest_table, frame_channels)
  if binding.no_description then return end

  local xt, descr = binding.xtouch or binding.fader, binding.description

  if type(xt) == 'function' then
    xt = xt(cursor, self.state)
  end
  if xt == nil and binding.vu then
    local vu = binding.vu
    if type(vu) == 'function' then
      vu = vu(cursor, self.state)
    end
    xt = 'channels[' .. vu .. '].VU Meter'
  end
  if xt ~= nil and descr == nil then
    if binding.schema ~= nil then
      descr = "Switch to " .. binding.schema
    elseif binding.cursor_step ~= nil then
      if binding.cursor_step < 0 then
        descr = "Move frame left by " .. (-binding.cursor_step)
      else
        descr = "Move frame right by " .. binding.cursor_step
      end
    else
      descr = 'UNDOCUMENTED'
    end
  end
  -- rprint(binding)
  -- print(xt, '::', descr)
  if xt ~= nil and descr ~= nil then
    -- dest_table[reformat(xt)] = descr
    local deep_path, event = description_key(xt, frame_channels)
    create_path(dest_table, deep_path, 1, event, descr)
  end
end


function SchemaManager:get_descriptions(program)
  local ret = table.create {}
  local schemas = table.create {}
  if program == nil then program = self.prog end

  for id, schema_fun in pairs(program.schemas) do
    schemas[id] = schema_fun(self.xtouch, program.state)
  end

  local cursor = table.create {channel=''}
  for id, schema in pairs(schemas) do
    if schema.frame ~= nil then
      -- print('*', schema.frame.name)
      cursor[schema.frame.name] = '##'
    end
  end

  for id, schema in pairs(schemas) do
    local dt = table.create {
      name=schema.name,
      assign=table.create {},
      frame=table.create{},
      frame_channels=schema.frame ~= nil and condense_sequence(schema.frame.channels) or nil
    }
    if schema.assign ~= nil then
      for _, binding in ipairs(schema.assign) do
        self:analyze_binding(cursor, binding, dt.assign, dt.frame_channels)
      end
    end
    if schema.frame ~= nil then
      -- print(schema.frame.name)
      for _, binding in ipairs(schema.frame.assign) do
        self:analyze_binding(cursor, binding, dt.frame, dt.frame_channels)
      end
    end
    ret[id] = dt
  end

  return ret
end


function SchemaManager:compile_binding(binding)
  if binding.fader ~= nil then return FaderBinding(binding, self) end
  if binding.led ~= nil then return LedBinding(binding, self) end
  if binding.screen ~= nil then return ScreenBinding(binding, self) end
  if binding.renoise ~= nil then return SimpleBinding(binding, self) end
  if binding.xtouch ~= nil then return SimpleBinding(binding, self) end
  if binding.vu ~= nil and binding.vu ~= '' then return VuBinding(binding, self) end
  print("Unhandled binding")
  rprint(binding)
  print("========= Unhandled binding")
end


function SchemaManager:auto_callback(a)
  local ret = deepcopy(a)
  local inner = a.callback or function() end
  local callback = inner
  if a.cursor_step then
    local frame_name = self.current_schema.frame.name
    local step = a.cursor_step
    callback = function(cursor, state)
      local frame = self.cursor['_frame_' .. frame_name]
      local min = 1
      local max = #frame.values - #frame.channels + 1
      frame.start = frame.start + step
      if frame.start > max then frame.start = max end
      if frame.start < min then frame.start = min end
      self:execute_compiled_schema_stack(self.current_stack)
      inner(cursor, state)
    end
  elseif a.schema then
    callback = function(cursor, state)
      local names = self:eval(a.schema)
      inner(cursor, state)
      self:execute_compiled_schema_stack(names)
      -- self.state.current_schema.value = names[#names]
    end
  elseif a.frame == 'update' then
    local cursor = self:copy_cursor()
    callback = function(c, state) self:execute_compiled_schema_stack(self.current_stack) inner(c, state) end
  end
  ret.callback = callback
  return ret
end


function SchemaManager:compile_schema(schema)
  local ret = deepcopy(schema)
  self.current_schema = schema
  if schema.assign ~= nil then
    ret.assign = table.create {}
    for i = 1, #schema.assign do
      local b = self:compile_binding(self:auto_callback(schema.assign[i]))
      if b ~= nil then ret.assign[i] = b end
    end
  end
  if schema.frame ~= nil and schema.frame.assign ~= nil then
    local assign = table.create {}
    for c = 1, #self:eval(ret.frame.channels) do
      assign[c] = table.create {}
      for i = 1, #schema.frame.assign do
        local b = self:compile_binding(self:auto_callback(schema.frame.assign[i]))
        if b ~= nil then assign[c][i] = b end
      end
    end
    ret.frame.assign = assign
  end
  return ret
end


function SchemaManager:compile_program(program)
  local ret = table.create {
    name = program.name,
    number = program.number,
    description = program.description,
    state = program.state,
    schemas = table.create {},
    startup = deepcopy(program.startup)
  }
  -- if ret.state == nil then ret.state = renoise.Document.create(program.name .. '-state') {} end
  -- if ret.state.current_schema == nil then
    -- ret.state:add_property('current_schema', renoise.Document.ObservableString('none'))
  -- end

  for k, v in pairs(program.schemas) do
    ret.schemas[k] = self:compile_schema(v(self.xtouch, ret.state))
  end

  return ret
end

function dump_state(state, ...)
  local path = {...}
  for i = 1, #path do
    state = state and state[path[i]]
  end
  print(table.concat(path, '.'), state)
end

function SchemaManager:execute_compiled_schema_stack(schema_stack)
  self.mm:prepare_update()
  -- self.state.current_schema.value = schema_stack[#schema_stack]

  print("STATE")
  dump_state(self.state, 'modifiers', 'shift')
  dump_state(self.state, 'modifiers', 'option')
  dump_state(self.state, 'modifiers', 'control')
  dump_state(self.state, 'modifiers', 'alt')
  dump_state(self.state, 'current_param')
  dump_state(self.state, 'current_track')
  dump_state(self.state, 'current_device')
  dump_state(self.state, 'current_schema')
  print("+++++")

  for i = 1, #schema_stack do
    -- print("Executing", schema_stack[i])
    local schema = self.compiled_program.schemas[schema_stack[i]]
    self.current_schema = schema

    if schema.frame then
      if schema.frame.before then schema.frame.before(schema.frame, self.state) end
      local frame = self:setup_frame(schema.frame)
      self:execute_compiled_frame(schema, frame)
      if schema.frame.after then schema.frame.after(frame.channels, frame.values, frame.start, self.state) end
    end

    if schema.assign then
      for _, binding in ipairs(schema.assign) do
        binding:update(self.mm)
      end
    end
  end
  self.mm:finalize_update()
  self.current_stack = schema_stack
end


function SchemaManager:execute_compiled_frame(schema, frame)
  self.current_frame = frame

  if frame.start > #frame.values then frame.start = #frame.values end
  if frame.start < 1 then frame.start = 1 end

  local nv = 1 + #frame.values - frame.start
  local nc = #frame.channels
  local n = nv < nc and nv or nc

  for c = 1, n do
    self.cursor.channel = frame.channels[c]
    self.cursor[frame.name] = frame.values[frame.start + c - 1]
    for _, a in ipairs(schema.frame.assign[c]) do
      a:update(self.mm)
    end
  end

  for c = n + 1, #frame.channels do
    self.cursor.channel = frame.channels[c]
    self.cursor[frame.name] = 0
    for _, a in ipairs(schema.frame.assign) do
      print(a)
      oprint(a)
      rprint(a)
      if a and a.update then a:update(self.mm) end
    end
  end

  self.current_frame = nil
  self.cursor[frame.name] = nil
  self.cursor.channel = nil
end
