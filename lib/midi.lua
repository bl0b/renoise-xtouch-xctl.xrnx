function XTouch:open()
  -- print(self.in_name, self.out_name)
  xpcall(function()
    if self.in_name ~= '' then
      self.input = renoise.Midi.create_input_device(self.in_name, {self, self.parse_msg}, {self, self.parse_msg})
    end
    if self.out_name ~= '' then
      self.output = renoise.Midi.create_output_device(self.out_name)
    end
  end, function(err)
  end)
  -- if not self.input.is_open then
    -- print("Couldn't open Input MIDI port " .. self.in_name)
  -- end
  -- if not self.output.is_open then
    -- print("Couldn't open Output MIDI port " .. self.in_name)
  -- end

  if      self.output ~= nil
      and self.output.is_open
      and self.input ~= nil
      and self.input.is_open then
    -- self:clear_stuff()
    renoise.tool():add_timer({self, self.ping}, self.ping_period)
    self.pong = false
    self.is_alive.value = false
    self:ping()
  end
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
    self.output:send(msg)
  end
end


function XTouch:ping()
  if self.output == nil or not self.output.is_open then
    -- print('[xtouch] no MIDI connection')
    return
  end
  -- if not (self.output ~= nil and self.output.is_open) then
  --   self:open()
  --   if not (self.output ~= nil and self.output.is_open) then
  --     -- print("not pinging")
  --     return
  --   end
  -- end
  -- print('Ping', self.pong, type(self.is_alive), self.is_alive)
  if self.pong then
    if self.is_alive.value == false then
      self.is_alive.value = true
      print("[xtouch] Connected!")
      local f
      f = function() print("[xtouch] Reset") self.force_reset:bang() renoise.tool().app_idle_observable:remove_notifier(f) end
      renoise.tool().app_idle_observable:add_notifier(f)
    end
    self.pong = false
  else
    if self.is_alive.value then
      self.was_alive = true
      print("[xtouch] Disconnected!")
      self.model.value = 'none'
      -- self:save_state()
    end
    self.is_alive.value = false
  end
  self.output:send({0xf0, 0, 0, 0x66, 0x14, 0, 0xf7})  -- I guess 0x14 mimics the x-air mixer
end


function XTouch:parse_msg(msg)
  local cmd = bit.rshift(msg[1], 4)
  local chan = bit.band(msg[1], 0xF)
  local label, value
  if cmd == 0xF then
    if #msg == 18 and msg[2] == 0 and msg[3] == 0 and msg[4] == 0x66 and (
          (msg[5] == 0x58 and msg[6] == 0x01)  -- X-Touch
          or
          (msg[5] == 0x14 and msg[6] == 0x06)  -- X-Touch compact
        ) then
      self.pong = true
      --self.channels[1].rec.led.value = 2
      -- if not self.is_alive.value then
        -- if self.was_alive then self:load_state() end
        -- self.is_alive.value = true
        -- self.was_alive = true
      -- end
      if     msg[5] == 0x58 and msg[6] == 0x01 then self.model.value = ' X-Touch'
      elseif msg[5] == 0x14 and msg[6] == 0x06 then self.model.value = ' X-Touch Compact'
      end
    end
  elseif cmd == 0x9 or cmd == 0x8 then
    label = self.note_map[msg[2] + 1]
    value = (cmd == 0x9 and msg[3] > 0 and 1 or 0)
  elseif cmd == 0xB then
    if msg[2] == 0x3c then
      label = self.transport.jog_wheel.delta
    else
      local channel = msg[2] - 15
      if channel >= 1 and channel <= 8 then
        label = self.channels[msg[2] - 15].encoder.delta
      end
    end
    label.value = 0
    value = bit.band(msg[3], 0x3f)
    if bit.band(msg[3], 0x40) == 0x40 then
      value = -value
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
  elseif cmd ~= 0xF then
    print_msg("Received (not handled)", msg)
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
    error("Send strip called with nil channel.")
  end
  -- print('[send_strip] channel =', channel, type(channel))
  local screen = self.channels[channel].screen
  local flag = screen.inverse.value and 0x40 or 0
  local col = match_color(screen.color[1].value, screen.color[2].value, screen.color[3].value)
  local msg = {0xf0, 0, 0, 0x66, 0x58, 0x1F + channel, flag + col, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0xf7}
  --[[
  print('sending screen')
  print('-- line1 <' .. screen.line1.value .. '>')
  print('-- line2 <' .. screen.line2.value .. '>')
  print('-- inverse=' .. (screen.inverse.value and 'true' or 'false'))
  print('-- color ' .. screen.color[1].value .. ', ' .. screen.color[1].value .. ', ' .. screen.color[1].value .. ' => ' .. col)
  ]]--
  str2arr(screen.line1.value, msg, 1)
  str2arr(screen.line2.value, msg, 2)
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


-- send message for faders
-- (channel) -> (outfunc, value) -> nil
function XTouch:_fader(channel)
  local last_midi_value = -1
  return function()
    local t = os.clock()
    -- if t < self.fader_timestamp[channel] + .023 then
      --print('too short', t, self.fader_timestamp[channel])
      -- return
    -- end
    -- self.fader_timestamp[channel] = t
    if self.fader_origin_xtouch[channel] then
      self.fader_origin_xtouch[channel] = false
      -- print("[xtouch] skipping fader update because it came from the X-Touch in the first place")
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
    --print('timestamp', t, 'last', self.fader_timestamp[channel])
    if midi_value ~= last_midi_value then
      -- print("[xtouch] send fader ", midi_value, bit.band(midi_value, 0x7f), bit.rshift(midi_value, 7))
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
