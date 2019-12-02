function SchemaManager:compile_binding(binding, suffix)
  -- print('compile binding')
  if binding.fader ~= nil then return FaderBinding(binding, self, suffix) end
  if binding.led ~= nil then return LedBinding(binding, self, suffix) end
  if binding.scribble ~= nil then return ScreenBinding(binding, self, suffix) end
  if binding.renoise ~= nil then return SimpleBinding(binding, self, suffix) end
  if binding.xtouch ~= nil then return SimpleBinding(binding, self, suffix) end
  if binding.vu ~= nil and binding.vu ~= '' then return VuBinding(binding, self, suffix) end
  print("[xtouch] Unhandled binding")
  rprint(binding)
  print("[xtouch] ========= Unhandled binding")
end


function SchemaManager:auto_callback(a)
  local ret = deepcopy(a)
  local inner = a.callback or function() end
  local callback = inner
  if a.cursor_step then
    local frame_name = a.cursor_name or self.current_schema.frame.name
    local step = a.cursor_step
    callback = function(cursor, state)
      local frame = self.cursor['_frame_' .. frame_name]
      local min = 1
      local max = #frame.values - #frame.channels + 1
      frame.start = frame.start + step
      if frame.start > max then frame.start = max end
      if frame.start < min then frame.start = min end
      inner(cursor, state)
      self:execute_compiled_schema_stack(self.current_stack, true)
    end
  elseif a.page then
    callback = function(cursor, state)
      if not self.mm:can_update() then return end
      local name = self:eval(a.page)
      inner(cursor, state)
      self:select_page(name)
      -- self.state.current_schema.value = names[#names]
    end
  elseif a.frame == 'update' or a.frame == 'refresh' then
    if ret.callback then
      print("[xtouch] Warning: do not use 'callback' with frame='update'. Use 'before' and 'after' instead.")
    end
    local cursor = self:copy_cursor()
    local before = ret.before or function() end
    local after = ret.after or function() end
    local keep_values = a.frame == 'refresh'
    callback = function(c, state)
      -- print("ENTER CALLBACK")
      -- print('execute BEFORE')
      local before_status = before(c, state)
      -- print("STATUS=", before_status)
      if before_status == false then
        -- print("EXIT CALLBACK")
        return
      end
      -- print('execute FRAME')
      self:execute_compiled_schema_stack(self.current_stack, keep_values)
      -- print('execute AFTER')
      after(c, state)
      -- print("EXIT CALLBACK")
    end
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
      local suffix = ' -- ' .. c
      assign[c] = table.create {}
      for i = 1, #schema.frame.assign do
        local b = self:compile_binding(self:auto_callback(schema.frame.assign[i]), suffix)
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

function SchemaManager:execute_compiled_schema_stack(schema_stack, keep_values)
  -- print('[xtouch] execute_compiled_schema_stack', #schema_stack)
  if not self.mm:prepare_update() then return end

  for i = 1, #schema_stack do
    -- print("Executing", schema_stack[i])
    local schema = self.compiled_program.schemas[schema_stack[i]]
    self.current_schema = schema

    if schema.frame then
      -- if schema.frame.before then self.mm:add_before(function() schema.frame.before(schema.frame, self.state) end) end
      local cursor_frame = self.cursor['_frame_' .. schema.frame.name]
      if schema.frame.before then schema.frame.before(schema.frame, self.state) end
      local frame = self:setup_frame(schema.frame, keep_values and cursor_frame.values)
      self:execute_compiled_frame(schema, frame)
      if schema.frame.after then self.mm:add_after(function() schema.frame.after(frame.channels, frame.values, frame.start, self.state) end) end
    end

    if schema.assign then
      for _, binding in ipairs(schema.assign) do
        binding:update(self.mm)
      end
    end
  end
  self.current_stack = schema_stack
  self.mm:finalize_update()
  -- print("[xtouch] Done updating.")
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
