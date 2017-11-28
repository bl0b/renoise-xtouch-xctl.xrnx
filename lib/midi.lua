function XTouch:open()
  self.input = renoise.Midi.create_input_device(self.in_name, {self, self.parse_msg}, {self, self.parse_msg})
  self.output = renoise.Midi.create_output_device(self.out_name)
  if not self.input.is_open then
    print("Couldn't open Input MIDI port " .. self.in_name)
  end
  if not self.output.is_open then
    print("Couldn't open Output MIDI port " .. self.in_name)
  end
end  


function XTouch:send(msg)
  print_msg('Sending', msg)
  if not self.output.is_open then
    self:open()
  end
  if self.output.is_open then
    self.output:send(msg)
  end
end


function XTouch:ping()
  if not self.output.is_open then
    self:open()
    if not self.output.is_open then
      print("not pinging")
      return
    end
  end
  --print('Ping')
  if self.pong then
    if not self.is_alive then
      print("Connected to X-Touch!!")
    end
    self.pong = false
    --self.tracks._1.rec.led = 1
  else
    if self.is_alive then
      print("Lost X-Touch!!")
      self:save_state()
    end
    --self.tracks._1.rec.led = 0
    self.is_alive = false
  end
  self.output:send({0xf0, 0, 0, 0x66, 0x14, 0, 0xf7})  -- I guess 0x14 mimics the x-air mixer
end


function XTouch:parse_msg(msg)
  local cmd = bit.rshift(msg[1], 4)
  local chan = bit.band(msg[1], 0xF)
  local label, value
  if cmd == 0xF then
    if #msg == 18 and msg[2] == 0 and msg[3] == 0 and msg[4] == 0x66 and msg[5] == 0x58 and msg[6] == 0x01 then
      self.pong = true
      --self.channels[1].rec.led.value = 2
      if not self.is_alive then
        self:load_state()
        self.is_alive = true
      end
    end
  elseif cmd == 0x9 or cmd == 0x8 then
    label = self.note_map[msg[2] + 1]
    value = (cmd == 0x9 and msg[3] > 0 and 1 or 0)
  elseif cmd == 0xB then
    if msg[2] == 0x3c then
      label = self.transport.jog_wheel.delta
    else
      label = self.channels[msg[2] - 15].encoder.delta
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
  print("in process")
  rprint(label)
  for i = 1, #label do
    prop = prop[label[i]]
  end
  prop.value = value
end


function XTouch:send_strip(channel)
  local screen = self.channels[channel].screen
  local flag = screen.inverse.value and 0x40 or 0
  local msg = {0xf0, 0, 0, 0x66, 0x58, 0x1F + channel, flag + match_color(screen.color[1].value, screen.color[2].value, screen.color[3].value), 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0xf7}
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
    print(v)
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
  return function()
    local last_midi_value = -1
    local last_timestamp = 0
    print("fader", channel)
    --rprint(self.fader_origin_xtouch)
    if self.fader_origin_xtouch[channel] then
      self.fader_origin_xtouch[channel] = false
      print("skipping fader update because it came from the X-Touch in the first place")
      return
    end
    local pb = 0xdf + channel
    local value
    if channel == 9 then
      value = self.channels.main.fader.value
    else
      value = self.channels[channel].fader.value
    end
    value = math.floor(16380 * value)
    local t = os.clock()
    print('timestamp', t)
    if value ~= last_midi_value and t > (last_timestamp + .2) then
      print("send fader ", value, bit.band(value, 0x7f), bit.rshift(value, 7))
      self:send({pb, bit.band(value, 0x7f), bit.rshift(value, 7)})
      last_midi_value = value
      last_timestamp = t
    end
  end
end


-- send message for LEDs
-- (channel) -> (outfunc, value) -> nil
function XTouch:_led(observable, number)
  return function()
    print("send led ", observable.value)
    self:send({0x90, number, observable.value})
  end
end

-- send message for an LCD digit
-- (observable, cc number) -> () -> nil
function XTouch:_lcd(observable, cc)
  return function()
    local value = bit.band(observable.value, 0x7f)
    local cc_dot = cc + bit.rshift(bit.band(observable.value, 0x80), 3)
    print("cc_dot =", cc_dot)
    self:send({0xb0, cc_dot, value})
  end
end