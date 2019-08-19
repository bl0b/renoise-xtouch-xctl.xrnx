local state_filename = os.currentdir() .. '/XTouchSchemaManager.state'



local fader_to_value = function(x)
  return math.db2lin(math.fader2db(-96, 3, x))
end

local value_to_fader = function(x)
  return math.db2fader(-96, 3, math.lin2db(x))
end



function tablediff(t1, t2)
  local added = {}
  local removed = {}
  local changed = {}

  local k1 = table.keys(t1)
  local k2 = table.keys(t2)

  table.sort(k1)
  table.sort(k2)

  local i2 = 1
  local i1 = 1
  while i1 <= #k1 and i2 <= #k2 do
    if k1[i1] < k2[i2] then
      table.insert(removed, k1[i1])
      i1 = i1 + 1
    elseif k1[i1] > k2[i2] then
      table.insert(added, k2[i2])
      i2 = i2 + 1
    else
      if t1[k1[i1]] ~= t2[k2[i2]] then
        table.insert(changed, k1[i1])
      end
      i1 = i1 + 1
      i2 = i2 + 1
    end
  end
  while i1 <= #k1 do
    table.insert(removed, k1[i1])
    i1 = i1 + 1
  end
  while i2 <= #k2 do
    table.insert(added, k2[i2])
    i2 = i2 + 1
  end

  return changed, removed, added
end


function to_xtouch(s)
  return s:sub(1, 6) == 'xtouch'
end


class "SchemaManager" (renoise.Document.DocumentNode)


function SchemaManager:__init(xtouch, program)
  self.cursor = table.create {}
  self.xtouch = xtouch
  self.prog = table.copy(program)
  self.state = self.prog.state
  self.state:add_property('current_schema', renoise.Document.ObservableString('none'))

  -- oprint(self.state.current_schema)

  self.registry = table.create {assign=table.create {}}

  self.undo_buffer = table.create {}

  renoise.tool().app_release_document_observable:add_notifier(function()
    self:unbind_from_song()
  end)
  renoise.tool().app_new_document_observable:add_notifier(function()
    self:rebind_to_song()
  end)

  for schema_name, func in pairs(self.prog.schemas) do
    self.prog.schemas[schema_name] = func(self.xtouch, self.prog.state)
  end

  for i, schema_name in ipairs(self.prog.startup) do
    local schema = self.prog.schemas[schema_name]
    self:push_schema(schema)
    self.state.current_schema.value = schema_name

  end

  self.xtouch.is_alive:add_notifier(function()
    if self.xtouch.is_alive.value then
      self:rebind_to_song()
    else
      self:unbind_from_song()
    end
  end)
end

local renoise_song = 'renoise.song().'

function SchemaManager:unbind_from_song()
  self:clear_assigns()
  if self.xtouch.vu_enabled then
    self.xtouch:cleanup_LED_support()
  end
end


function SchemaManager:rebind_to_song()
  if self.xtouch.vu_enabled then
    self.xtouch:init_LED_support()
  end
  self:push_schema(self.current_schema)
end

local eval_env = {
  delta = 'delta',
  press = 'press',
  release = 'release',
  touch = 'touch',
  move = 'move',
  renoise = renoise,
  state = 0,
  xtouch = 0
}

function SchemaManager:lua_eval(str)
  local ok, reta, retb
  assert(type(str) == 'string', 'All bindables must be given as strings')
  str = str:gsub('(cursor.(%w+))', function(_, name) return self.cursor[name] end)
  eval_env.state = self.state
  eval_env.xtouch = self.xtouch
  ok, reta, retb = xpcall(
    function()
      return setfenv(assert(loadstring("return " .. str)), eval_env)()
    end,
    function(err)
      print("An error occurred evaluating «" .. str .. "»")
      print(err)
      print(debug.traceback())
    end)
    if ok then
      -- print("[lua_eval]", str, "OK", reta, retb)
      return reta, retb
    else
      -- print("[lua_eval]", str, " FAILED")
    end
end



function SchemaManager:register(source, callback)
  if type(source) ~= 'string' then
    error("I do not want to register non-string bindable", type(source))
  end
  if self.registry.assign[source] ~= nil then
    error("A callback was already registered for " .. source)
  end
  self.registry.assign[source] = callback
end

function SchemaManager:unregister(source, callback)
  if self.registry.assign[source] == nil then
    error("Can't unregister bindable that is not currently assigned")
  end
  self.registry.assign[source] = nil
end

function SchemaManager:is_registered(source)
  return self.registry.assign[source] ~= nil
end



function SchemaManager:unassign(source, undoing)
  if source == nil then return end
  if not self:is_registered(source) then return end
  if not undoing then self.undo_buffer:insert({'assign', source, self.registry.assign[source]}) end
  if source:sub(1, 1) == 'x' then
    local widget, event = self:lua_eval(source)
    self.xtouch:off(widget, event)
  else
    local src = self:lua_eval(source)
    local typ = type(src)
    if typ:sub(1, 10) == 'Observable' then
      if src:has_notifier(self.registry.assign[source]) then
        src:remove_notifier(self.registry.assign[source])
      end
    elseif typ == 'DeviceParameter' then
      if src.value_observable:has_notifier(self.registry.assign[source]) then
        src.value_observable:remove_notifier(self.registry.assign[source])
      end
    else
      error('Required to unassign unhandled thing: ' .. typ .. ' ' .. source)
    end
  end
  self:unregister(source)
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

function SchemaManager:assign(source, callback, undoing)
  -- print('+++', source)
  if source == nil then return end
  if self:is_registered(source) then
    xpcall(
      function() self:unassign(source, undoing) end,
      function(err)
        print("[xtouch:WRN] There was an error unassigning", source)
        print(err)
        print(debug.traceback())
      end
    )
  end
  if not undoing then self.undo_buffer:insert({'unassign', source, callback}) end
  assert(type(source) == 'string', 'I only accept bindables as strings')
  if source:sub(1, 1) == 'x' then
    -- X-Touch binding
    local widget, event = self:lua_eval(source)
    -- print('XTOUCH BINDING', widget.path.value, event)
    self.xtouch:on(widget, event, callback)
    self:register(source, callback)
  else
    local src = self:lua_eval(source)
    if string.sub(type(src), 1, 10) == 'Observable' then
      -- local last_timestamp = 0
      local cursor = self:copy_cursor()
      local f = function()
        -- local t = os.clock()
        -- if t > (last_timestamp + .023) then
          callback(cursor, self.state)
          -- last_timestamp = t
        -- end
      end
      self:register(source, f)
      src:add_notifier(f)
    elseif type(src) == 'DeviceParameter' then
      -- local last_timestamp = 0
      local cursor = self:copy_cursor()
      local f = function()
        -- local t = os.clock()
        -- if t > (last_timestamp + .023) then
          callback(cursor, self.state)
          -- last_timestamp = t
        -- end
      end
      self:register(source, f)
      src.value_observable:add_notifier(f)
    else
      error("Can't find what to do for " .. source .. " of type " .. type(src))
    end
  end
end

function SchemaManager:clear_assigns()
  for source, _ in pairs(self.registry.assign) do
    self:unassign(source)
  end
end

function SchemaManager:assign_fader(fader, observable, with_value, from_fader, to_fader)
  if fader == nil then return end
  if with_value == nil then return end

  local vol_val = with_value.value
  local cursor = self:copy_cursor()

  if from_fader == nil then from_fader = function(c, s, v) return fader_to_value(v) end end
  if to_fader == nil then to_fader = function(c, s, v) return value_to_fader(v) end end

  local widget = self:lua_eval(fader)

  local set_fader = function()
    local tmp = to_fader(cursor, self.state, with_value.value)
    if tmp ~= nil then widget.value.value = tmp end
  end

  self:assign(observable, set_fader)

  self:assign(fader .. ',move', function(event, widget)
    local tmp = from_fader(cursor, self.state, widget.value.value)
    if tmp ~= nil then with_value.value = tmp end
  end)

  set_fader()
end

function SchemaManager:assign_fader_nil(fader, observable)
  if fader == nil then return end
  if self:is_registered(fader .. ',move') then
    self:unassign(fader .. ',move')
  end

  local widget = self:lua_eval(fader)

  widget.value.value = 0
end

function SchemaManager:assign_led(led, observable, value, to_led)
  if led == nil then return end
  if to_led == nil then to_led = function(cursor, state, x) return x and 2 or 0 end end
  local cursor = self:copy_cursor()
  led.value = 0
  local led_callback = function(event, widget) led.value = to_led(cursor, self.state, self:eval(value, cursor)) end
  self:assign(observable, led_callback)
  led.value = to_led(cursor, self.state, self:eval(value, cursor))
end

function SchemaManager:assign_led_nil(led, observable)
  if led == nil then return end
  led.value = 0
end

function SchemaManager:assign_screen(screen, trigger, value, renderer)
  if screen == nil then return end
  local cursor = self:copy_cursor()
  local state = self.state
  -- print("Screen channel", screen._channel_)
  cursor.channel = 0 + screen._channel_.value
  self:assign(trigger,  function(event, widget)
                          renderer(cursor, state, screen, value)
                          self.xtouch:send_strip(cursor.channel)
                        end)
  renderer(cursor, state, screen, value)
  self.xtouch:send_strip(cursor.channel)
end

function SchemaManager:assign_screen_nil(screen, trigger)
  if screen == nil then return end
  local channel = self.cursor.channel
  screen.line1.value = ''
  screen.line2.value = ''
  screen.color[1].value = 0
  screen.color[2].value = 0
  screen.color[3].value = 0
  screen.inverse.value = false
  self.xtouch:send_strip(channel)
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


function SchemaManager:make_cursor_step_callback(step)
  local frame_name = self.current_schema.frame.name
  return function(cursor, state)
    self:frame_update(cursor, function(cursor, state)
      local frame = self.cursor['_frame_' .. frame_name]
      local min = 1
      local max = #frame.values - #frame.channels + 1
      frame.start = frame.start + step
      if frame.start > max then frame.start = max end
      if frame.start < min then frame.start = min end
    end)
  end
end



function SchemaManager:execute_one(a, undo, ingroup)
  local callback = a.callback
  if a.cursor_step then
    callback = self:make_cursor_step_callback(self:eval(a.cursor_step))
  elseif a.schema then
    local orig = a.callback or function(...) end
    callback = function(cursor, state)
      local name = self:eval(a.schema)
      orig(cursor, state)
      self:push_schema(self.prog.schemas[name])
      self.state.current_schema.value = name
    end
  elseif a.frame == 'update' then
    local orig = a.callback or function(...) end
    local cursor = self:copy_cursor()
    callback = function(c, state) self:frame_update(cursor, orig) end
  elseif callback and a.immediate then
    -- force call upon assignment
    callback(self.cursor, self.state)
  end
  if a.xtouch then
    local cursor = self:copy_cursor()
    local wrapped = function(event, widget) callback(cursor, self.state, event, widget) end
    self:assign(self:eval(a.xtouch), wrapped)
  elseif a.renoise then
    local cursor = self:copy_cursor()
    local wrapped = function() callback(cursor, self.state) end
    self:assign(self:eval(a.renoise), wrapped)
  elseif a.fader then
    if undo then
      self:assign_fader_nil(self:eval(a.fader), self:eval(a.obs))
    else
      self:assign_fader(self:eval(a.fader), self:eval(a.obs), self:eval(a.value), a.from_fader, a.to_fader)
    end
  elseif a.led then
    if undo then
      self:assign_led_nil(self:eval(a.led), self:eval(a.obs))
    else
      self:assign_led(self:eval(a.led), self:eval(a.obs), a.value, a.to_led)
    end
  elseif a.vu then
    if undo then
      self.xtouch:untap(self:eval(a.vu))
    else
      self.xtouch:tap(self:eval(a.track), self:eval(a.at), self:eval(a.vu), self:eval(a.post))
    end
  elseif a.screen then
    if undo then
      self:assign_screen_nil(self:eval(a.screen), self:eval(a.trigger))
    else
      self:assign_screen(self:eval(a.screen), self:eval(a.trigger), self:eval(a.value), a.render)
    end
  end
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


function SchemaManager:execute_frame(schema, frame)
  self.current_frame = frame

  if frame.start > #frame.values then frame.start = #frame.values end
  if frame.start < 1 then frame.start = 1 end

  local nv = 1 + #frame.values - frame.start
  local nc = #frame.channels
  local n = nv < nc and nv or nc

  for c = 1, n do
    self.cursor.channel = frame.channels[c]
    self.cursor[frame.name] = frame.values[frame.start + c - 1]
    -- print('channel', self.cursor.channel, 'set to', frame.name, self.cursor[frame.name])
    for _, a in ipairs(schema.frame.assign) do
      self:execute_one(a)
    end
  end

  for c = n + 1, #frame.channels do
    self.cursor.channel = frame.channels[c]
    self.cursor[frame.name] = 0
    -- print('channel', self.cursor.channel, 'set to nil')
    for _, a in ipairs(schema.frame.assign) do
      self:execute_one(a, true)
    end
  end

  self.current_frame = nil
  self.cursor[frame.name] = nil
  self.cursor.channel = nil
end


function SchemaManager:execute(schema)
  self.undo_buffer = table.create {}

  if schema.mode == 'full' then
    -- print("CLEAR ASSIGNS")
    self:clear_assigns()
  end

  self.current_schema = schema
  
  if schema.frame then
    if schema.frame.before then schema.frame.before(schema.frame, self.state) end
    
    local frame = self:setup_frame(schema.frame)
    self:execute_frame(schema, frame)

    if schema.frame.after then schema.frame.after(frame.channels, frame.values, frame.start, self.state) end
  end

  if schema.assign then
    for _, a in ipairs(schema.assign) do
      self:execute_one(a)
    end
  end
end


function SchemaManager:frame_update(cursor, callback)
  self:undo()
  callback(cursor, self.state)
  self:push_schema(self.current_schema)
end

function SchemaManager:push_schema(new_schema)
  self.current_schema = schema
  self:execute(new_schema)
end

function SchemaManager:undo()
  for i, command in ripairs(self.undo_buffer) do
    if command[1] == 'assign' then
      self:assign(command[2], command[3], true)
    elseif command[1] == 'unassign' then
      self:unassign(command[2], true)
    end
  end
end
