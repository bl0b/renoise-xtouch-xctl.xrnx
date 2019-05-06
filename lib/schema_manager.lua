local state_filename = os.currentdir() .. '/XTouchSchemaManager.state'

class "SchemaManager" (renoise.Document.DocumentNode)

function SchemaManager:save_state()
  self:save_as(state_filename)
end

function SchemaManager:load_state()
  if io.exists(state_filename) then
    self:load_from(state_filename)
    self:refresh()
  end
end

function SchemaManager:__init(xtouch)
  self.schema_stack = table.create({})
  self.assign_stack = table.create({})
  self.cursor = table.create({})
  self.xtouch = xtouch
  self.assign_table = table.create({})
  self.command_buffer = table.create({})
  self.command_stack = table.create()
end

function SchemaManager:unassign(source, event)
  if self.assign_table[{source, event}] == nil then
    return
  end
  -- print('unassign', source, event, self.assign_table[{source, event}])
  if to_xtouch(source, event) then
    -- xtouch:off(source, event)
    self.command_buffer:insert({'off', source, event, self.assign_table[{source, event}]})
  else
    -- source:remove_notifier(self.assign_table[{source, event}])
    self.command_buffer:insert({'remove_notifier', source, self.assign_table[{source, event}]})
  end
  -- self.assign_table[{source, event}] = nil
end

function SchemaManager:copy_cursor()
  local copy = {}
  -- print('copy_cursor', self.cursor)
  -- rprint(self.cursor)
  for k, v in pairs(self.cursor) do
    -- print(k, string.sub(k, 1, 7), v)
    if string.sub(k, 1, 7) ~= '_frame_' then
      copy[k] = v
      end
  end
  -- print('copy', copy)
  -- rprint(copy)
  return copy
end

function SchemaManager:assign(source, event, callback)
  if callback == nil then
    callback = event
    event = nil
  end
  -- oprint(self)
  if self.assign_table[{source, event}] ~= nil then
    self.unassign(source)
  end
  if to_xtouch(source, event) then
    -- X-Touch binding
    -- print('binding on x-touch', source.path or source, event)
    -- self.xtouch:on(source, event, callback)
    self.command_buffer:insert({'on', source, event, callback})
    -- self.assign_table[{source, event}] = callback
  elseif string.sub(type(source), 1, 10) == 'Observable' then
    -- print('binding on renoise')
    local last_timestamp = 0
    local f = function()
      local t = os.clock()
      if t > (last_timestamp + .023) then
        callback()
        last_timestamp = t
      end
    end
    -- self.assign_table[{source, event}] = f
    -- source:add_notifier(f)
    self.command_buffer:insert({'add_notifier', source, f})
  elseif type(source) == 'DeviceParameter' then
    -- print('binding on renoise')
    local last_timestamp = 0
    local f = function()
      local t = os.clock()
      if t > (last_timestamp + .023) then
        callback()
        last_timestamp = t
      end
    end
    -- self.assign_table[{source, event}] = f
    -- source:add_notifier(f)
    self.command_buffer:insert({'add_notifier', source.value_observable, f})
  else
    error("Can't find what to do for a " .. type(source) .. " for event " .. (event == nil and 'nil' or event))
  end
end

function SchemaManager:clear_assigns()
  for source_event, _ in pairs(self.assign_table) do
    unassign(source_event[1], source_event[2])
  end
  self.assign_table = table.create({})
end

function SchemaManager:assign_fader(fader, observable, with_value, from_fader, to_fader)
  local vol_val = with_value.value
  local cursor = self:copy_cursor()
  if from_fader == nil then from_fader = function(c, s, v) return fader_to_value(v) end end
  if to_fader == nil then to_fader = function(c, s, v) return value_to_fader(v) end end
  -- print('assign fader', fader, observable, with_value, from_fader, to_fader)
  self.command_buffer:insert(function()
    fader.value.value = to_fader(cursor, self.state, with_value.value)
  end)
  self:assign(fader, 'move', function(event, widget)
    with_value.value = from_fader(cursor, self.state, fader.value.value)
  end)
  -- self.command_buffer:insert(function() if vol_val == 0 then with_value.value = 1 else with_value.value = 0 end end)
  self:assign(observable, function()
    fader.value.value = to_fader(cursor, self.state, with_value.value)
  end)
  self.command_buffer:insert(function()
    with_value.value = vol_val
  end)
end

function SchemaManager:assign_fader_nil(fader, observable)
  -- self:unassign(fader, 'move')
  -- self:unassign(observable)
  self.command_buffer:insert(function() fader.value.value = 0 end)
end

function SchemaManager:assign_led(led, observable, value, to_led)
  if to_led == nil then to_led = function(cursor, state, x) return x and 2 or 0 end end
  local cursor = self:copy_cursor()
  local state = self.state
  self.command_buffer:insert(function() led.value = to_led(cursor, state, self:eval(value, cursor)) end)
  self:assign(observable, function(event, widget) led.value = to_led(cursor, state, self:eval(value, cursor)) end)
end

function SchemaManager:assign_led_nil(led, observable)
  -- self:unassign(observable)
  self.command_buffer:insert(function() led.value = 0 end)
end

function SchemaManager:assign_screen(screen, trigger, value, renderer)
  -- rprint(self.cursor)
  local cursor = self:copy_cursor()
  local state = self.state
  -- print('type(value)', type(value))
  -- rprint(cursor)
  self:assign(trigger,  function(event, widget)
                          renderer(cursor, state, screen, value)
                          self.xtouch:send_strip(cursor.channel)
                        end)
  self.command_buffer:insert(function()
    renderer(cursor, state, screen, value)
    self.xtouch:send_strip(cursor.channel)
    -- print('screen updated', cursor.channel)
  end)
end

function SchemaManager:assign_screen_nil(screen, trigger)
  local channel = self.cursor.channel
  -- self:unassign(trigger)
  self.command_buffer:insert(function()
    screen.line1.value = ''
    screen.line2.value = ''
    screen.color[1].value = 0
    screen.color[2].value = 0
    screen.color[3].value = 0
    screen.inverse.value = false
    self.xtouch:send_strip(channel)
  end)
end


function SchemaManager:eval(v, cursor)
  if cursor == nil then cursor = self.cursor end
  
  if type(v) == 'function' then
    local status, ret = xpcall(function() return v(cursor, self.state) end, function(err) print('error in eval', err) oprint(err) rprint(err) end)
    -- print('xpcall status', status, ret)
    return ret
  end

  return v
end


function SchemaManager:make_cursor_step_callback(step)
  local frame_name = self.current_schema.frame.name
  -- print('current frame', frame_name)
  
  local state = self.state

  return function(cursor, state)
    self:frame_update(function(cursor, state)
      local frame = cursor['_frame_' .. frame_name]
      local min = 1
      local max = #frame.values - #frame.channels + 1
      frame.start = frame.start + step
      if frame.start > max then frame.start = max end
      if frame.start < min then frame.start = min end
      -- print('frame sizes: channels', #frame.channels, 'values', #frame.values, 'min', min, 'max', max, 'step', step, 'start', frame.start)
    end)
  end
end

function SchemaManager:compile_one(a, undo)
    local callback = a.callback
    if a.cursor_step then
      callback = self:make_cursor_step_callback(self:eval(a.cursor_step))
    elseif a.schema then
      if a.schema == 'exit' then
        callback = function(cursor, state)
          self:pop()
        end
      else
        callback = function(cursor, state)
          self:push(self:eval(a.schema))
        end
      end
    elseif a.frame == 'update' then
      local orig = a.callback
      callback = function(cursor, state) self:frame_update(orig) end
    end
    if a.xtouch then
      local cursor = self:copy_cursor()
      local state = self.state
      if undo then
        self:unassign(self:eval(a.xtouch), self:eval(a.event))
      else
        local wrapped = function(event, widget) callback(cursor, state, event, widget) end
        self:assign(self:eval(a.xtouch), self:eval(a.event), wrapped)
      end
    elseif a.renoise then
      if undo then
        self:unassign(self:eval(a.renoise))
      else
        self:assign(self:eval(a.renoise), callback)
      end
    elseif a.fader then
      -- rprint(a)
      -- print('fader', self:eval(a.fader))
      -- print('obs', self:eval(a.obs))
      -- print('value', self:eval(a.value))
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
      -- oprint(self)
      -- oprint(self.xtouch)
      if undo then
        self.command_buffer:insert({'untap', self:eval(a.vu)})
      else
        self.command_buffer:insert({'tap', self:eval(a.track), self:eval(a.at), self:eval(a.vu), self:eval(a.post)})
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
  end
  self.cursor[frame_key] = {
    name = frame.name,
    -- min = function() return frame.min(self.cursor, self.state) end,
    -- max = function() return frame.max(self.cursor, self.state) - #frame.channels + 1 end,
    -- start = frame.min(self.cursor, self.state),
    start = start,
    values = self:eval(frame.values),
    channels = self:eval(frame.channels)

  }
  return self.cursor['_frame_' .. frame.name]
end


function SchemaManager:compile_frame(schema, frame)
  self.current_frame = frame

  if frame.start > #frame.values then frame.start = #frame.values end
  if frame.start < 1 then frame.start = 1 end

  local nv = 1 + #frame.values - frame.start
  local nc = #frame.channels
  local n = nv < nc and nv or nc

  for c = 1, n do
    self.cursor.channel = frame.channels[c]
    self.cursor[frame.name] = frame.values[frame.start + c - 1]
    -- print(frame.name, 'start', frame.start, 'current', self.cursor[frame.name], 'channel', self.cursor.channel)
    for _, a in ipairs(schema.frame.assign) do
      self:compile_one(a)
    end
  end

  for c = n + 1, #frame.channels do
    for _, a in ipairs(schema.frame.assign) do
      self:compile_one(a, true)
    end
  end

  self.current_frame = nil
  self.cursor[frame.name] = nil
  self.cursor.channel = nil
end


function SchemaManager:compile(schema)
  local backup
  if schema.mode == 'full' then
    backup = self.assign_table
    self.assign_table = table.create({})
  end

  self.current_schema = schema
  self.state = schema.state
  
  self.command_buffer = table.create()
  if schema.frame then
    local frame = self:setup_frame(schema.frame)
    self:compile_frame(schema, frame)
  end
  self.frame_commands = self.command_buffer

  if schema.mode == 'full' then
    self.assign_table = backup
  end

  self.command_buffer = table.create()
  for _, a in ipairs(schema.assign) do
    self:compile_one(a)
  end
  self.main_commands = self.command_buffer
  
  self.command_buffer = nil
end

function SchemaManager:do_commands(commands)
  local method
  for _, command in ipairs(commands) do
    if type(command) == 'function' then
      -- print('DO COMMAND <function>')
      command()
    else
      -- print("DO COMMAND", command[1], command[2], command[3], command[4])
      method = command[1]
      if method == 'on' then
        self.xtouch:on(command[2], command[3], command[4])
      elseif method == 'off' then
        self.xtouch:off(command[2], command[3], command[4])
      elseif method == 'add_notifier' then
        command[2]:add_notifier(command[3])
      elseif method == 'remove_notifier' then
        command[2]:remove_notifier(command[3])
      elseif method == 'tap' then
        self.xtouch:tap(command[2], command[3], command[4], command[5])
      elseif method == 'untap' then
        self.xtouch:untap(command[2])
      else
        print("unknown command to do", command[1])
      end
    end
  end
end

function SchemaManager:undo_commands(commands)
  local method
  for _, command in ripairs(commands) do
    if type(command) ~= 'function' then
      -- print("UNDO COMMAND", command[1], command[2], command[3], command[4])
      method = command[1]
      if method == 'on' then
        self.xtouch:off(command[2], command[3], command[4])
      elseif method == 'off' then
        self.xtouch:on(command[2], command[3], command[4])
      elseif method == 'add_notifier' then
        command[2]:remove_notifier(command[3])
      elseif method == 'remove_notifier' then
        command[2]:add_notifier(command[3])
      elseif method == 'tap' then
        self.xtouch:untap(command[4])
      elseif method == 'untap' then
        -- pass
      else
        print("unknown command to undo", command[1])
      end
    end
  end
end


function SchemaManager:frame_update(callback)
  local schema = self.schema_stack[#self.schema_stack]
  if not schema.frame then return end
  self:undo_commands(self.command_stack[#self.command_stack])
  callback(self.cursor, self.state)
  self.command_buffer = table.create()
  -- local frame = self.cursor['_frame_' .. schema.frame.name]
  local frame = self:setup_frame(schema.frame)
  self.current_schema = schema
  self:compile_frame(schema, frame)
  self.current_schema = nil
  self.command_buffer = self.command_buffer
  self:do_commands(self.command_buffer)
  self.command_stack[#self.command_stack] = self.command_buffer
end

function SchemaManager:push(new_schema)
  -- rprint(new_schema)
  self:compile(new_schema)
  self.schema_stack:insert(new_schema)
  self:do_commands(self.main_commands)
  self.command_stack:insert(self.main_commands)
  self:do_commands(self.frame_commands)
  self.command_stack:insert(self.frame_commands)
end

function SchemaManager:pop()
  self:undo_commands(self.command_stack[#self.command_stack])
  self.command_stack:remove()
  self.assign_stack:remove()
  self.state = self.schema_stack[#self.schema_stack].state or table.create({})
  self:adjust_to(self.assign_stack[#self.assign_stack])
end


function SchemaManager:adjust_to(other_assign)
  local a = self.assign_table
  local b = other_assign

  for k, v in ipairs(a) do
    if b[k] ~= v then
      self:unassign(unpack(k))
    end
  end
  for k, v in ipairs(b) do
    if a[k] ~= v then
      self:assign(unpack(k), v)
    end
  end
end
