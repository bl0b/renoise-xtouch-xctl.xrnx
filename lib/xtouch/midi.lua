function XTouch:open()
  -- print('[X-Touch] open', self.in_name, self.out_name)
  xpcall(function()
    if self.in_name.value ~= '' then
      self.input = renoise.Midi.create_input_device(self.in_name.value, {self, self.parse_msg})
    end
    if self.out_name.value ~= '' then
      self.output = renoise.Midi.create_output_device(self.out_name.value)
    end
  end, function(err)
  end)
  -- if not self.input.is_open then
    -- print("Couldn't open Input MIDI port " .. self.in_name)
  -- end
  -- if not self.output.is_open then
    -- print("Couldn't open Output MIDI port " .. self.in_name)
  -- end

  -- if      self.output ~= nil
  --     and self.output.is_open
  --     and self.input ~= nil
  --     and self.input.is_open then
  --   -- self:clear_stuff()
  --   renoise.tool():add_timer({self, self.ping}, self.ping_period)
  --   self.pong = false
  --   self.is_alive.value = false
  --   self:ping()
  -- end
end


function XTouch:clear_stuff()
  for i, obs in pairs(self.led_map) do
    if obs ~= nil then
      self:send({0x90, i - 1, 0})
    end
  end
  for i = 1, 8 do self:send_strip(i) self:_enc_led(i) end
end


function XTouch:send(msg)
  -- print_msg('Sending', msg)
  if self.output == nil or not self.output.is_open then
    self:open()
  end
  if self.output ~= nil and self.output.is_open then
    pcall(function() self.output:send(msg) end)
  end
end


-- function XTouch:ping()
--   if self.output == nil or not self.output.is_open then
--     -- print('[xtouch] no MIDI connection')
--     return
--   end
--   -- if not (self.output ~= nil and self.output.is_open) then
--   --   self:open()
--   --   if not (self.output ~= nil and self.output.is_open) then
--   --     -- print("not pinging")
--   --     return
--   --   end
--   -- end
--   -- print('Ping', self.pong, type(self.is_alive), self.is_alive)
--   -- print('[xtouch] ping', self.is_alive, self.pong)
--   if self.pong then
--     if self.is_alive.value == false then
--       self.is_alive.value = true
--       print("[xtouch][midi]  Connected!")
--       local f
--       f = function() print("[xtouch][midi] Reset") self.force_reset:bang() renoise.tool().app_idle_observable:remove_notifier(f) end
--       renoise.tool().app_idle_observable:add_notifier(f)
--     end
--     self.pong = false
--   else
--     if self.is_alive.value then
--       self.was_alive = true
--       print("[xtouch][midi]  Disconnected!")
--       self.model.value = 'none'
--       -- self:save_state()
--     end
--     self.is_alive.value = false
--   end
--   self.output:send({0xf0, 0, 0, 0x66, 0x14, 0, 0xf7})  -- I guess 0x14 mimics the x-air mixer
-- end


function XTouch:parse_msg(msg)
  local cmd = bit.rshift(msg[1], 4)
  local chan = bit.band(msg[1], 0xF)
  local label, value
  if cmd == 0x9 or cmd == 0x8 then
    label = self.note_map[msg[2] + 1]
    value = (cmd == 0x9 and msg[3] > 0 and 1 or 0)
    if msg[2] >= 104 and msg[2] <= 112 then
      -- check for off-by-one!
      -- print('sending back on channel', msg[2] - 103)
      local midi_value = math.floor(16380 * self.channels[msg[2] - 103].fader.value)
      if self.compact_compat then self:send({0xdf + msg[2] - 103, bit.band(midi_value, 0x7f), bit.rshift(midi_value, 7)}) end  -- send back last edited value or the Compact fader will reset to where it was before the touch event.
    end
  elseif cmd == 0xB then
    if msg[2] == 0x3c then
      label = self.transport.jog_wheel.delta
    elseif msg[2] == 0x2E then
      label = self.expression.value
    else
      local channel = msg[2] - 15
      if channel >= 1 and channel <= 8 then
        label = self.channels[msg[2] - 15].encoder.delta
      end
    end
    label.value = 0
    if msg[2] ~= 0x2E then
      value = bit.band(msg[3], 0x3f)
      if bit.band(msg[3], 0x40) == 0x40 then
        value = -value
      end
    else
      value = msg[3]
    end
    --print(label, value)
  elseif cmd == 0xE then
    if chan == 8 then
      label = self.channels.main.fader.value
    else
      label = self.channels[chan + 1].fader.value
    end
    self.fader_origin_xtouch[chan + 1] = true
    value = (msg[2] + msg[3] * 128) / 16380.
  end
  if label ~= nil then
    --oprint(label)
    -- print("new value", value, "dest. type", type(label))
    if type(label) == 'ObservableBoolean' then
      label.value = (value ~= 0)
    else
      label.value = value
    end
--    self:process(label, value)
  -- elseif cmd ~= 0xF then
    -- print_msg("[xtouch][midi] Received (not handled)", msg)
  end
end


function XTouch:process(label, value)
  local prop = self
  for i = 1, #label do
    prop = prop[label[i]]
  end
  prop.value = value
end


function XTouch:send_strip(channel)
  if channel == nil then
    error("[xtouch][midi] Send strip called with nil channel.")
  end
  -- print('[send_strip] channel =', channel, type(channel))
  local screen = self.channels[channel].screen
  local flag = screen.inverse.value and 0x40 or 0
  local col = match_color(screen.color[1].value, screen.color[2].value, screen.color[3].value)
  local msg = {0xf0, 0, 0, 0x66, 0x58, 0x1F + channel, flag + col, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0xf7}
  local l1 = string.sub(screen.line1.value, 1, 7)
  local l2 = string.sub(screen.line2.value, 1, 7)
  --[[
  print('sending screen')
  print('-- line1 <' .. l1 .. '>')
  print('-- line2 <' .. l2 .. '>')
  print('-- inverse=' .. (screen.inverse.value and 'true' or 'false'))
  print('-- color ' .. screen.color[1].value .. ', ' .. screen.color[1].value .. ', ' .. screen.color[1].value .. ' => ' .. col)
  -- ]]--
  str2arr(l1, msg, 1)
  str2arr(l2, msg, 2)
  self:send(msg)
end


-- send message for encoder LEDs
-- (channel) -> (outfunc, value) -> nil
function XTouch:_enc_led(channel)
  local cc1 = 47 + channel
  local cc2 = 55 + channel
  return function()
    local v = bit.band(self.channels[channel].encoder.led.value, 0x1fff)
    --print(v)
    self:send({0xb0, cc1, bit.rshift(v, 6)})
    self:send({0xb0, cc2, bit.band(v, 0x3f)})
  end
end


-- send message for vu meter
-- (channel) -> (outfunc, value) -> nil
function XTouch:_vu(observable, channel)
  channel = (channel - 1) * 16
  return function()
    local value = 8 * observable.value
    if value > 15 then value = 15 end
    self:send({0xd0, channel + value})
  end
end


-- function XTouch:fader_timer_func()
--   for i = 1, 9 do
--     local fader = self.channels[i].fader
--     if not fader.state.value and fader.value.value ~= self.fader_last_sent[i] then
--       -- print(i, fader.state.value, fader.value.value, self.fader_last_sent[i])
--       local target_value = math.floor(16380 * fader.value.value)
--       local delta
--       if target_value > self.fader_last_sent[i] then
--         delta = math.min(4000, target_value - self.fader_last_sent[i])
--       else
--         delta = math.max(-4000, target_value - self.fader_last_sent[i])
--       end
--       print(i, delta)
--       self.fader_last_sent[i] = self.fader_last_sent[i] + delta
--       self:send({0xdf + i, bit.band(self.fader_last_sent[i], 0x7f), bit.rshift(self.fader_last_sent[i], 7)})
--     else
--       self.fader_last_sent[i] = math.floor(16380 * fader.value.value)
--     end
--   end
-- end


-- send message for faders
-- (channel) -> (outfunc, value) -> nil
function XTouch:_fader(channel)
  local last_midi_value = -1
  return function()
    if self.channels[channel].fader.state.value then  -- user is currently inputting data
      return
    end
    local pb = 0xdf + channel
    local fader_value
    if channel == 9 then
      fader_value = self.channels.main.fader.value
    else
      fader_value = self.channels[channel].fader.value
    end
    local midi_value = math.floor(16380 * fader_value.value)
    -- local threshold = 20
    if midi_value ~= last_midi_value then
      -- if midi_value < last_midi_value - threshold then
      --   local v2 = midi_value + threshold
      --   self:send({pb, bit.band(v2, 0x7f), bit.rshift(v2, 7)})
      -- elseif midi_value > last_midi_value + threshold then
      --   local v2 = midi_value - threshold
      --   self:send({pb, bit.band(v2, 0x7f), bit.rshift(v2, 7)})
      -- end
      self:send({pb, bit.band(midi_value, 0x7f), bit.rshift(midi_value, 7)})
      last_midi_value = midi_value
    end
  end
end


-- send message for LEDs
-- (channel) -> (outfunc, value) -> nil
function XTouch:_led(observable, number)
  return function()
    --print("send led ", observable.value)
    self:send({0x90, number, observable.value})
  end
end

-- send message for an LCD digit
-- (observable, cc number) -> () -> nil
function XTouch:_lcd(observable, cc)
  return function()
    local value = bit.band(observable.value, 0x7f)
    local cc_dot = cc + bit.rshift(bit.band(observable.value, 0x80), 3)
    --print("cc_dot =", cc_dot)
    self:send({0xb0, cc_dot, value})
  end
end
