function SchemaManager:compile_binding(binding)
  -- print('compile binding')
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
  elseif a.page then
    callback = function(cursor, state)
      local name = self:eval(a.page)
      inner(cursor, state)
      self:select_page(name)
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
    pages = program.pages,
    startup_page = program.startup_page
  }
  -- print("Compile program, startup page", program.startup_page)
  -- if ret.state == nil then ret.state = renoise.Document.create(program.name .. '-state') {} end
  -- if ret.state.current_schema == nil then
    -- ret.state:add_property('current_schema', renoise.Document.ObservableString('none'))
  -- end

  for k, v in pairs(program.schemas) do
    ret.schemas[k] = self:compile_schema(v(self.xtouch, ret.state))
  end

  -- print("COMPILED PROGRAM")
  -- rprint(ret)
  return ret
end

function SchemaManager:execute_compiled_schema_stack(schema_stack)
  self.mm:prepare_update()

  for i = 1, #schema_stack do
    -- print("Executing", schema_stack[i])
    local schema = self.compiled_program.schemas[schema_stack[i]]
    self.current_schema = schema

    if schema.frame then
      if schema.frame.before then self.mm:add_before(function() schema.frame.before(schema.frame, self.state) end) end
      local frame = self:setup_frame(schema.frame)
      self:execute_compiled_frame(schema, frame)
      if schema.frame.after then self.mm:add_after(function() schema.frame.after(frame.channels, frame.values, frame.start, self.state) end) end
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
      -- print(a)
      -- oprint(a)
      -- rprint(a)
      if a and a.update then a:update(self.mm) end
    end
  end

  self.current_frame = nil
  self.cursor[frame.name] = nil
  self.cursor.channel = nil
end
