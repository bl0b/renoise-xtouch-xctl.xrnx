
local deferred = require('lib/promise')

local xtouch = nil

local msg_eq = function(msg1, msg2, n)
  -- print('msg_eq', table.concat(msg1, ','), table.concat(msg2, ','))
  if n == nil and #msg1 ~= #msg2 then
    return false
  end
  n = n or #msg1
  for i = 1, n do
    if msg1[i] ~= msg2[i] then return false end
  end
  return true
end


local devices = {}
local output_name = 'not set'

local extract_serial = function(msg)
  local s = {}
  for i = 7, #msg - 2 do
    s[i - 6] = string.char(msg[i])
  end
  return table.concat(s, '')
end

local pong_gen = function(input_name, pong_promise)
  return function(msg)
    if msg_eq({0xf0, 0, 0, 0x66, 0x58, 0x01}, msg, 6) then
      pong_promise:resolve({input_name, output_name, 'X-Touch', extract_serial(msg)})
    elseif msg_eq({0xf0, 0, 0, 0x66, 0x14, 0x06}, msg, 6) then
      pong_promise:resolve({input_name, output_name, 'X-Touch Compact', extract_serial(msg)})
    end
  end
end


local prepare_inputs = function(promise)
  for index, name in ipairs(renoise.Midi.available_input_devices()) do
    local pong = pong_gen(name, promise)
    -- print('OPEN INPUT DEVICE', name)
    xpcall(function() devices[index] = renoise.Midi.create_input_device(name, pong, pong) end, function() devices[index] = {is_open = false} end)
  end
end

local close_inputs = function(t)
  for _, d in ipairs(devices) do if d.is_open then d:close() end end
  return t
end


local ConnectionState = {
  DISCONNECTED = 0,
  DISCOVERING = 1,
  CONNECTED = 2,
  [0] = 'DISCONNECTED',
  [1] = 'DISCOVERING',
  [2] = 'CONNECTED',
}

local connection_state = renoise.Document.ObservableNumber(-1)

local setup_heartbeat_monitor = function(in_device_name, out_device_name)
  local heartbeat_count = 0
  local output = renoise.Midi.create_output_device(out_device_name)
  local heartbeat_recv = function(msg)
    if msg_eq({240,0,32,50,88,84,0,247}, msg) then
      heartbeat_count = heartbeat_count + 1
      if math.mod(heartbeat_count, 2) == 1 then
        output:send({0xf0, 0, 0, 0x66, 0x14, 0, 0xf7})
      end
    end
  end
  local input = renoise.Midi.create_input_device(in_device_name, nil, heartbeat_recv)
  local last_heartbeat_count = 0
  local heartbeat_monitor
  heartbeat_monitor = function()
    if connection_state.value == ConnectionState.CONNECTED and last_heartbeat_count == heartbeat_count then
      connection_state.value = ConnectionState.DISCONNECTED
      renoise.tool():remove_timer(heartbeat_monitor)
      if input.is_open then input:close() end
      if output.is_open then output:close() end
    end
    last_heartbeat_count = heartbeat_count
  end
  renoise.tool():add_timer(heartbeat_monitor, 2200)
end


local discover = function()
  local last_out_device_index = nil

  local p = deferred.new(prepare_inputs)
  local p_resolved = false

  local next_output
  next_output = function()
    local output_devices = renoise.Midi.available_output_devices()
    if output_devices[last_out_device_index] == nil then
      last_out_device_index = nil
    end
    last_out_device_index, output_name = next(renoise.Midi.available_output_devices(), last_out_device_index)

    if output_name == nil or p_resolved then
      renoise.tool():remove_timer(next_output)
      if not p_resolved then
        p:reject()
      end
      return
    end

    if string.find(output_name, 'WDM') ~= nil then  -- For some reasons the scribble strip SYSEX are not sent with a (WDM) device.
      next_output()
      return
    end

    -- print('OPEN OUTPUT DEVICE', output_name)
    xpcall(function()
      local output = renoise.Midi.create_output_device(output_name)
      output:send({0xf0, 0, 0, 0x66, 0x14, 0, 0xf7})
      output:close()
    end, function(err)
      print(err)
    end)
  end

  if connection_state.value ~= ConnectionState.DISCONNECTED
      or renoise.tool():has_timer(next_output) then
    return
  end

  connection_state.value = ConnectionState.DISCOVERING
  p:next(function(t)
    local in_name, out_name, model, serial = t[1], t[2], t[3], t[4]
    p_resolved = true
    -- print(string.format('Model: %s   Serial# %s', model, serial))
    -- print(string.format('MIDI In: %s', in_name))
    -- print(string.format('MIDI Out: %s', out_name))
    xtouch:close()
    xtouch.model.value = model
    xtouch.serial.value = serial
    xtouch.in_name.value = in_name
    xtouch.out_name.value = out_name
    xtouch:open()
    connection_state.value = ConnectionState.CONNECTED
    xtouch.force_reset:bang()
    setup_heartbeat_monitor(in_name, out_name)
  end):next(nil, function(err)
    xtouch:close()
    xtouch.model.value = 'none'
    xtouch.serial.value = 'N/A'
    xtouch.in_name.value = 'none'
    xtouch.out_name.value = 'none'
    connection_state.value = ConnectionState.DISCONNECTED
    -- print('X-Touch not detected.')
    if err ~= nil then print(err) print(debug.traceback()) end
  end)
  renoise.tool():add_timer(next_output, 100)
end


local connection_state_monitor = function()
  if connection_state.value == ConnectionState.DISCONNECTED then
    if not renoise.tool():has_timer(discover) then
      renoise.tool():add_timer(discover, 1000)
    end
    xtouch.is_alive.value = false
  elseif connection_state.value == ConnectionState.CONNECTED then
    if renoise.tool():has_timer(discover) then
      renoise.tool():remove_timer(discover)
    end
    xtouch.is_alive.value = true
  end
end

local bonsoir_xtouch = function(_xtouch)
  xtouch = _xtouch
  connection_state:add_notifier(connection_state_monitor)
  connection_state.value = ConnectionState.DISCONNECTED
end

return bonsoir_xtouch