-- 20171110 bl0b
class "XTouch" (renoise.Document.DocumentNode)


-- Match a color to one in the X-Touch
-- X-Touch defines:
-- 0 turn off
-- 1 Red
-- 2 Green
-- 3 Yellow
-- 4 Blue
-- 5 Magenta
-- 6 Cyan
-- 7 White
function match_color(r, g, b)
  local xtcol = {{255, 0, 0}, {0, 255, 0}, {255, 255, 0}, {0, 0, 255}, {255, 0, 255}, {0, 255, 255}, {255, 255, 255}}
  local best = 7
  local bestproj = 1000000
  if r == 0 and g == 0 and b == 0 then
    return 0
  end
  for i = 1, #xtcol do
    local dr = (xtcol[i][1] - r)
    local dg = (xtcol[i][2] - g)
    local db = (xtcol[i][3] - b)
    dr = dr * dr
    dg = dg * dg
    db = db * db
    local proj = math.sqrt(dr + dg + db)
    if (proj < bestproj) then
      bestproj = proj
      best = i
    end
  end
  return best
end





-- dump a midi message in the terminal
-- (prefix, message) -> nil
function print_msg(s, msg)
  for i = 1, #msg do
    --print("msg byte", i, msg[i])
    --rprint(msg[i])
    --oprint(msg[i])
    s = s .. ' ' .. string.format('%02x', msg[i] or {state = false, led = 0})
  end
  print(s)
end



-- copy the contents of a scribble strip line into a SYSEX at the right place. see usage in send_screen.
-- (line, sysex, line number) -> nil
function str2arr(str, msg, line)
  local ret = {}
  local ofs = 7 * line
  for i = 1, #str do
    msg[ofs + i] = string.byte(str:sub(i,i))
    --table.insert(ret, str.byte(i))
  end
  for i = #str + 1, 7 do
    --table.insert(ret, {state = false, led = 0})
    msg[ofs + i] = 0
  end
end


-- send message for screens
-- (channel) -> (outfunc, screen table) -> nil
function send_screen(channel)
  return function (out, screen)
    local flag = screen.inverse.value and 0x40 or 0
    local msg = {0xf0, 0, 0, 0x66, 0x58, 0x20 + channel, flag + match_color(screen.color[1].value, screen.color[2].value, screen.color[3].value), 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0xf7}
    str2arr(screen.line1.value, msg, 1)
    str2arr(screen.line2.value, msg, 2)
    out(msg)
  end
end



-- describe how to send what in an X-Touch track
-- (channel) -> [table]
function send_track(channel)
  return {
    screen = send_screen(channel),
    rec = send_led(channel),
    solo = send_led(channel + 8),
    mute = send_led(channel + 16),
    select = send_led(channel + 24),
    vu = send_vu(channel),
    fader = send_fader(channel)
  }
end




local state_filename = os.currentdir() .. '/XTouch.state'


function XTouch:save_state()
  self:save_as(state_filename)
end


-- Release resources
function XTouch:close()
  self.input:close()
  self.output:close()
  self.closed = true
  renoise.tool():remove_timer({self, self.ping})
  self:save_as(state_filename)
end


function XTouch:load_state()
  if io.exists(state_filename) then
    self:load_from(state_filename)
    for i = 1, 8 do self:send_strip(i) end
    self.channels = {self.tracks._1, self.tracks._2, self.tracks._3, self.tracks._4, self.tracks._5, self.tracks._6, self.tracks._7, self.tracks._8}
  end
end


function XTouch:open()
  self.input = renoise.Midi.create_input_device(self.in_name, {self, self.parse_msg}, {self, self.parse_msg})
  self.output = renoise.Midi.create_output_device(self.out_name)
  if not self.input.is_open then
    error("Couldn't open Input MIDI port " .. self.in_name)
  end
  if not (self.output.is_open and self.output.is_open) then
    error("Couldn't open Input MIDI port " .. self.in_name)
  end
end  

-- Controller class Ctor
function XTouch:__init(midiin, midiout, ping_period)
  print("CTOR XTouch")
  self.in_name = midiin
  self.out_name = midiout
  self:open()
  -- important! call super first
  --oprint(self.output) rprint(self.output)
  self.closed = false
  renoise.Document.DocumentNode.__init(self)
  --self.output:send({0xf0, 0x00, 0x00, 0x66, 0x58, 0x01, 0x30, 0x31, 0x35, 0x36, 0x34, 0x30, 0x33, 0x35, 0x39, 0x32, 0x41, 0xf7})
  
  self:add_properties {
    is_alive = false,
    main_fader = {state = 0, value = .75},
    encoder_assign = {
      track = {state = 0, led = 0},
      pan = {state = 0, led = 0},
      eq = {state = 0, led = 0},
      send = {state = 0, led = 0},
      plugin = {state = 0, led = 0},
      inst = {state = 0, led = 0}
    },
    display = {state = 0, led = 0},
    smpte_beats = {state = 0, led = 0},
    global_view = {state = 0, led = 0},
    midi_tracks = {state = 0, led = 0},
    inputs = {state = 0, led = 0},
    audio_tracks = {state = 0, led = 0},
    audio_inst = {state = 0, led = 0},
    aux = {state = 0, led = 0},
    buses = {state = 0, led = 0},
    outputs = {state = 0, led = 0},
    user = {state = 0, led = 0},
    flip = {state = 0, led = 0},
    function_ = {
      f1 = {state = 0, led = 0}, f2 = {state = 0, led = 0}, f3 = {state = 0, led = 0}, f4 = {state = 0, led = 0},
      f5 = {state = 0, led = 0}, f6 = {state = 0, led = 0}, f7 = {state = 0, led = 0}, f8 = {state = 0, led = 0}
    },
    modify = {shift = {state = 0, led = 0}, option = {state = 0, led = 0}, control = {state = 0, led = 0}, alt = {state = 0, led = 0}},
    automation = {
      read_off = {state = 0, led = 0}, write = {state = 0, led = 0}, trim = {state = 0, led = 0},
      touch = {state = 0, led = 0}, latch = {state = 0, led = 0}, group = {state = 0, led = 0}
    },
    utility = {save = {state = 0, led = 0}, undo = {state = 0, led = 0}, cancel = {state = 0, led = 0}, enter = {state = 0, led = 0}},
    transport = {
      marker = {state = 0, led = 0}, nudge = {state = 0, led = 0}, cycle = {state = 0, led = 0}, drop = {state = 0, led = 0},
      replace = {state = 0, led = 0}, click = {state = 0, led = 0}, solo = {state = 0, led = 0}, rewind = {state = 0, led = 0},
      forward = {state = 0, led = 0}, stop = {state = 0, led = 0}, play = {state = 0, led = 0}, record = {state = 0, led = 0}, jog_wheel = 0
    },
    bank = {left = {state = 0, led = 0}, right = {state = 0, led = 0}},
    channel = {left = {state = 0, led = 0}, right = {state = 0, led = 0}},
    left = {state = 0, led = 0},
    up = {state = 0, led = 0},
    down = {state = 0, led = 0},
    right = {state = 0, led = 0},
    zoom = {state = 0, led = 0},
    scrub = {state = 0, led = 0},
    lcd = {
      assignment = {left = 0, right = 0},
      bars_hours = {left = 0, middle = 0, right = 0},
      beats_minutes = {left = 0, right = 0},
      subdiv_seconds = {left = 0, right = 0},
      ticks_frames = {left = 0, middle = 0, right = 0}
    },
  }
  
  self:add_properties {
    tracks = {
      _1 = {
        screen = {color = {0, 255, 255}, line1 = 'Hello', line2 = 'Renoise', inverse = true},
        rec = {state = 0, led = 0},
        solo = {state = 0, led = 0},
        mute = {state = 0, led = 0},
        select = {state = 0, led = 0},
        vu = 0,
        fader = {state = 0, value = 0},
        encoder = {state = 0,delta = 0, led = 0}
      },
      _2 = {
        screen = {color = {0, 255, 0}, line1 = 'X-Touch', line2 = ' (XCtl)', inverse = true},
        rec = {state = 0, led = 0},
        solo = {state = 0, led = 0},
        mute = {state = 0, led = 0},
        select = {state = 0, led = 0},
        vu = 0,
        fader = {state = 0, value = 0},
        encoder = {state = 0,delta = 0, led = 0}
      },
      _3 = {
        screen = {color = {255, 255, 255}, line1 = 'Support', line2 = 'by bl0b', inverse = false},
        rec = {state = 0, led = 0},
        solo = {state = 0, led = 0},
        mute = {state = 0, led = 0},
        select = {state = 0, led = 0},
        vu = 0,
        fader = {state = 0, value = 0},
        encoder = {state = 0,delta = 0, led = 0}
      },
      _4 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = {state = 0, led = 0},
        solo = {state = 0, led = 0},
        mute = {state = 0, led = 0},
        select = {state = 0, led = 0},
        vu = 0,
        fader = {state = 0, value = 0},
        encoder = {state = 0, delta = 0, led = 0}
      },
      _5 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = {state = 0, led = 0},
        solo = {state = 0, led = 0},
        mute = {state = 0, led = 0},
        select = {state = 0, led = 0},
        vu = 0,
        fader = {state = 0, value = 0},
        encoder = {state = 0, delta = 0, led = 0}
      },
      _6 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = {state = 0, led = 0},
        solo = {state = 0, led = 0},
        mute = {state = 0, led = 0},
        select = {state = 0, led = 0},
        vu = 0,
        fader = {state = 0, value = 0},
        encoder = {state = 0, delta = 0, led = 0}
      },
      _7 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = {state = 0, led = 0},
        solo = {state = 0, led = 0},
        mute = {state = 0, led = 0},
        select = {state = 0, led = 0},
        vu = 0,
        fader = {state = 0, value = 0},
        encoder = {state = 0, delta = 0, led = 0}
      },
      _8 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = {state = 0, led = 0},
        solo = {state = 0, led = 0},
        mute = {state = 0, led = 0},
        select = {state = 0, led = 0},
        vu = 0,
        fader = {state = 0, value = 0},
        encoder = {state = 0, delta = 0, led = 0}
      }
    }
  }

  self.channels = {self.tracks._1, self.tracks._2, self.tracks._3, self.tracks._4, self.tracks._5, self.tracks._6, self.tracks._7, self.tracks._8}

  self:load_state()

  --oprint(self)

  local out = function(msg) self:send(msg) end

  --send_screen(0)(out, self.tracks._1.screen)

  for i = 1, 8 do
    self.channels[i].rec.led:add_notifier(self:_led(self.channels[i].rec.led, i - 1))
    self.channels[i].solo.led:add_notifier(self:_led(self.channels[i].solo.led, i + 7))
    self.channels[i].mute.led:add_notifier(self:_led(self.channels[i].mute.led, i + 15))
    self.channels[i].select.led:add_notifier(self:_led(self.channels[i].select.led, i + 23))
    self.channels[i].fader.value:add_notifier(self:_fader(i))
    self.channels[i].encoder.led:add_notifier(self:_enc_led(i))
    self.channels[i].vu:add_notifier(self:_vu(self.channels[i].vu, i))
    self:send_strip(i)
    self.channels[i].encoder.delta:add_notifier(function()
      local v = self.channels[i].vu.value + self.channels[i].encoder.delta.value * .1
      if v < 0 then v = 0 elseif v > 1 then v = 1 end
      self.channels[i].vu.value = v
    end)
    self.channels[i].encoder.delta:add_notifier(function()
      self.channels[i].encoder.led.value = self.channels[i].encoder.led.value + self.channels[i].encoder.delta.value
    end)
  end

  self.main_fader.value:add_notifier(self:_fader(9))

  for cc, obs in pairs({
      [96] = self.lcd.assignment.left,
      [97] = self.lcd.assignment.right,
      [98] = self.lcd.bars_hours.left,
      [99] = self.lcd.bars_hours.middle,
      [100] = self.lcd.bars_hours.right,
      [101] = self.lcd.beats_minutes.left,
      [102] = self.lcd.beats_minutes.right,
      [103] = self.lcd.subdiv_seconds.left,
      [104] = self.lcd.subdiv_seconds.right,
      [105] = self.lcd.ticks_frames.left,
      [106] = self.lcd.ticks_frames.middle,
      [107] = self.lcd.ticks_frames.right}) do
    rprint(obs)
    print("has CC #", cc)
    obs:add_notifier(self:_lcd(obs, cc))
  end
  --self.lcd.assignment.left:add_notifier(self:_lcd(self.lcd.assignment.left, 96))
  --self.lcd.assignment.right:add_notifier(self:_lcd(self.lcd.assignment.right, 97))
  
  self.lcd_digits = {
    self.lcd.assignment.left,
    self.lcd.assignment.right,
    self.lcd.bars_hours.left,
    self.lcd.bars_hours.middle,
    self.lcd.bars_hours.right,
    self.lcd.beats_minutes.left,
    self.lcd.beats_minutes.right,
    self.lcd.subdiv_seconds.left,
    self.lcd.subdiv_seconds.right,
    self.lcd.ticks_frames.left,
    self.lcd.ticks_frames.middle,
    self.lcd.ticks_frames.right
  }

  self.lcd_ascii = {
    [' '] = 0, ['!'] = 0x82, ['-'] = 0x40, ['_'] = 0x08, ['='] = 0x48,
    ['a'] = 0x5f, ['b'] = 0x7c, ['c'] = 0x58, ['d'] = 0x5e, ['e'] = 0x7b, ['f'] = 0x71, ['g'] = 0x6f, ['h'] = 0x74, ['i'] = 0x04, ['j'] = 0x0c, ['k'] = 0x76, ['l'] = 0x30, ['m'] = 0x37,
    ['n'] = 0x54, ['o'] = 0x5c, ['p'] = 0x73, ['q'] = 0x67, ['r'] = 0x50, ['s'] = 0x6d, ['t'] = 0x70, ['u'] = 0x1c, ['v'] = 0x3e, ['w'] = 0x7e, ['x'] = 0x52, ['y'] = 0x72, ['z'] = 0x5b,

    ['0'] = 0x3f, ['1'] = 0x06, ['2'] = 0x5b, ['3'] = 0x4f, ['4'] = 0x66, ['5'] = 0x6d, ['6'] = 0x7d, ['7'] = 0x07, ['8'] = 0x7f, ['9'] = 0x6f,

    ['A'] = 0x5f, ['B'] = 0x7c, ['C'] = 0x58, ['D'] = 0x5e, ['E'] = 0x7c, ['F'] = 0x71, ['G'] = 0x6f, ['H'] = 0x74, ['I'] = 0x04, ['J'] = 0x0c, ['K'] = 0x76, ['L'] = 0x60, ['M'] = 0x37,
    ['N'] = 0x54, ['O'] = 0x5c, ['P'] = 0x73, ['Q'] = 0x67, ['R'] = 0x50, ['S'] = 0x6d, ['T'] = 0x70, ['U'] = 0x1c, ['V'] = 0x3e, ['W'] = 0x7e, ['X'] = 0x52, ['Y'] = 0x72, ['Z'] = 0x5b
  }

  --self.tracks._1.screen.trigger:add_notifier((function(sender) return function(notification) print(notification) sender(self.out, self.tracks._1.screen) end end) (send_screen(1)))
  --self.tracks._1.screen.trigger:bang()

  self.note_map = {
  -- 0
    self.tracks._1.rec.state, self.tracks._2.rec.state, self.tracks._3.rec.state, self.tracks._4.rec.state, self.tracks._5.rec.state,
   -- 5
    self.tracks._6.rec.state, self.tracks._7.rec.state, self.tracks._8.rec.state, self.tracks._1.solo.state, self.tracks._2.solo.state,
  -- 10
    self.tracks._3.solo.state, self.tracks._4.solo.state, self.tracks._5.solo.state, self.tracks._6.solo.state, self.tracks._7.solo.state,
  -- 15
    self.tracks._8.solo.state, self.tracks._1.mute.state, self.tracks._2.mute.state, self.tracks._3.mute.state, self.tracks._4.mute.state,
  -- 20
    self.tracks._5.mute.state, self.tracks._6.mute.state, self.tracks._7.mute.state, self.tracks._8.mute.state, self.tracks._1.select.state,
  -- 25
    self.tracks._2.select.state, self.tracks._3.select.state, self.tracks._4.select.state, self.tracks._5.select.state, self.tracks._6.select.state,
  -- 30
    self.tracks._7.select.state, self.tracks._8.select.state, self.tracks._1.encoder.delta, self.tracks._2.encoder.delta, self.tracks._3.encoder.delta,
  -- 35
    self.tracks._4.encoder.delta, self.tracks._5.encoder.delta, self.tracks._6.encoder.delta, self.tracks._7.encoder.delta, self.tracks._8.encoder.delta,
  -- 40
    self.encoder_assign.track.state, self.encoder_assign.send.state, self.encoder_assign.pan.state, self.encoder_assign.plugin.state, self.encoder_assign.eq.state,
  -- 45
    self.encoder_assign.inst.state, self.bank.left.state, self.bank.right.state, self.channel.left.state, self.channel.right.state,
  -- 50
    self.flip.state, self.global_view.state, self.display.state, self.smpte_beats.state, self.function_.f1.state,
  -- 55
    self.function_.f2.state, self.function_.f3.state, self.function_.f4.state, self.function_.f5.state, self.function_.f6.state,
  -- 60
    self.function_.f7.state, self.function_.f8.state, self.midi_tracks.state, self.inputs.state, self.audio_tracks.state,
  -- 65
    self.audio_inst.state, self.aux.state, self.buses.state, self.outputs.state, self.user.state,
  -- 70
    self.modify.shift.state, self.modify.option.state, self.modify.control.state, self.modify.alt.state, self.automation.read_off.state,
  -- 75
    self.automation.write.state, self.automation.trim.state, self.automation.touch.state, self.automation.latch.state, self.automation.group.state,
  -- 80
    self.utility.save.state, self.utility.undo.state, self.utility.cancel.state, self.utility.enter.state, self.transport.marker.state,
  -- 85
    self.transport.nudge.state, self.transport.cycle.state, self.transport.drop.state, self.transport.replace.state, self.transport.click.state,
  -- 90
    self.transport.solo.state, self.transport.rewind.state, self.transport.forward.state, self.transport.stop.state, self.transport.play.state,
  -- 95,
    self.transport.record.state, self.up.state, self.down.state, self.left.state, self.right.state,
  -- 100
    self.zoom.state, self.scrub.state, nil, nil, self.tracks._1.fader.state,
  -- 105
    self.tracks._2.fader.state, self.tracks._3.fader.state, self.tracks._4.fader.state, self.tracks._5.fader.state, self.tracks._6.fader.state,
  -- 110
    self.tracks._7.fader.state, self.tracks._8.fader.state, self.main_fader.state, nil, nil,
  -- 115
    self.transport.solo.state, nil, nil, nil, nil,
  -- 120
    nil, nil, nil, nil, nil,
  -- 125
    nil, nil, nil
  }

  local led_map = {
  -- 0
    self.tracks._1.rec.led, self.tracks._2.rec.led, self.tracks._3.rec.led, self.tracks._4.rec.led, self.tracks._5.rec.led,
   -- 5
    self.tracks._6.rec.led, self.tracks._7.rec.led, self.tracks._8.rec.led, self.tracks._1.solo.led, self.tracks._2.solo.led,
  -- 10
    self.tracks._3.solo.led, self.tracks._4.solo.led, self.tracks._5.solo.led, self.tracks._6.solo.led, self.tracks._7.solo.led,
  -- 15
    self.tracks._8.solo.led, self.tracks._1.mute.led, self.tracks._2.mute.led, self.tracks._3.mute.led, self.tracks._4.mute.led,
  -- 20
    self.tracks._5.mute.led, self.tracks._6.mute.led, self.tracks._7.mute.led, self.tracks._8.mute.led, self.tracks._1.select.led,
  -- 25
    self.tracks._2.select.led, self.tracks._3.select.led, self.tracks._4.select.led, self.tracks._5.select.led, self.tracks._6.select.led,
  -- 30
    self.tracks._7.select.led, self.tracks._8.select.led, nil, nil, nil,
  -- 35
    nil, nil, nil, nil, nil,
  -- 40
    self.encoder_assign.track.led, self.encoder_assign.send.led, self.encoder_assign.pan.led, self.encoder_assign.plugin.led, self.encoder_assign.eq.led,
  -- 45
    self.encoder_assign.inst.led, self.bank.left.led, self.bank.right.led, self.channel.left.led, self.channel.right.led,
  -- 50
    self.flip.led, self.global_view.led, self.display.led, self.smpte_beats.led, self.function_.f1.led,
  -- 55
    self.function_.f2.led, self.function_.f3.led, self.function_.f4.led, self.function_.f5.led, self.function_.f6.led,
  -- 60
    self.function_.f7.led, self.function_.f8.led, self.midi_tracks.led, self.inputs.led, self.audio_tracks.led,
  -- 65
    self.audio_inst.led, self.aux.led, self.buses.led, self.outputs.led, self.user.led,
  -- 70
    self.modify.shift.led, self.modify.option.led, self.modify.control.led, self.modify.alt.led, self.automation.read_off.led,
  -- 75
    self.automation.write.led, self.automation.trim.led, self.automation.touch.led, self.automation.latch.led, self.automation.group.led,
  -- 80
    self.utility.save.led, self.utility.undo.led, self.utility.cancel.led, self.utility.enter.led, self.transport.marker.led,
  -- 85
    self.transport.nudge.led, self.transport.cycle.led, self.transport.drop.led, self.transport.replace.led, self.transport.click.led,
  -- 90
    self.transport.solo.led, self.transport.rewind.led, self.transport.forward.led, self.transport.stop.led, self.transport.play.led,
  -- 95,
    self.transport.record.led, self.up.led, self.down.led, self.left.led, self.right.led,
  -- 100
    self.zoom.led, self.scrub.led, nil, nil, self.tracks._1.fader.led,
  -- 105
    self.tracks._2.fader.led, self.tracks._3.fader.led, self.tracks._4.fader.led, self.tracks._5.fader.led, self.tracks._6.fader.led,
  -- 110
    self.tracks._7.fader.led, self.tracks._8.fader.led, self.main_fader.led, nil, nil,
  -- 115
    self.transport.solo.led
  }
  
  for i, obs in pairs(led_map) do
    if obs ~= nil then
      obs:add_notifier(self:_led(obs, i - 1))
    end
  end
  
  self.ping_func = function() self:ping() end
  self.ping_period = ping_period
  print("SELF.PING_PERIOD =", ping_period)
  renoise.tool():add_timer({self, self.ping}, ping_period)
  self.pong = true
  self.is_alive = false
  self:ping()
  
  
  self.channels[1].encoder.led.value = 0x2AA
  self.flip.state:add_notifier(function()
    if self.flip.state.value == 0 then
      return
    end
    if self.flip.led.value == 2 then
      self.flip.led.value = 0
      self:send_lcd_string(1, "hello world!")
    elseif self.flip.led.value == 1 then
      self.flip.led.value = self.flip.led.value + 1
      self:send_lcd_string(1, '=0123456789=')
    else
      self.flip.led.value = self.flip.led.value + 1
      self:send_lcd_string(1, "X-touch bl0b")
    end
  end)
end


function XTouch:send(msg)
  print_msg('Sending', msg)
  self.output:send(msg)
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
      label = self.transport.jog_wheel
    else
      label = self.channels[msg[2] - 15].encoder.delta
    end
    value = bit.band(msg[3], 0x3f)
    if bit.band(msg[3], 0x40) == 0x40 then
      value = -value
    end
    --print(label, value)
  elseif cmd == 0xE then
    if chan == 8 then
      label = self.main_fader.value
    else
      label = self.channels[chan + 1].fader.value
    end
    value = (msg[2] + msg[3] * 128) / 16380.
  end
  if label ~= nil then
    --oprint(label)
    --print("new value", value)
    label.value = value
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
  self.output:send(msg)
end


-- send message for encoder LEDs
-- (channel) -> (outfunc, value) -> nil
function XTouch:_enc_led(channel)
  local cc1 = 47 + channel
  local cc2 = 55 + channel
  return function()
    self:send({0xb0, cc1, bit.rshift(self.channels[channel].encoder.led.value, 6)})
    self:send({0xb0, cc2, bit.band(self.channels[channel].encoder.led.value, 0x3f)})
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
    local pb = 0xdf + channel
    local value
    if channel == 9 then
      value = self.main_fader.value
    else
      value = self.channels[channel].fader.value
    end
    value = math.floor(16380 * value)
    print("send fader ", value, bit.band(value, 0x7f), bit.rshift(value, 7))
    self:send({pb, bit.band(value, 0x7f), bit.rshift(value, 7)})
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


function XTouch:send_lcd_string(start_digit, str)
  print("send_lcd_digits")
  for i = 1, math.min(13 - start_digit, string.len(str)) do
    local c = self.lcd_ascii[string.sub(str, i, i)]
    print(string.sub(str, i, i), self.lcd_ascii[string.sub(str, i, i)])
    if c ~= nil then
      self.lcd_digits[start_digit].value = c
      start_digit = start_digit + 1
    end
  end
  rprint(self.lcd_digits)
end
