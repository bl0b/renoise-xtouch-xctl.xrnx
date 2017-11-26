function XTouch:init_annoyingly_big_data()
  self:add_properties {
    is_alive = false,
    encoder_assign = {
      track = self:init_button('encoder_assign.track'),
      pan = self:init_button('encoder_assign.pan'),
      eq = self:init_button('encoder_assign.eq'),
      send = self:init_button('encoder_assign.send'),
      plugin = self:init_button('encoder_assign.plugin'),
      inst = self:init_button('encoder_assign.inst')
    },
    display = self:init_button('display'),
    smpte_beats = self:init_button('smpte_beats'),
    global_view = self:init_button('global_view'),
    midi_tracks = self:init_button('midi_tracks'),
    inputs = self:init_button('inputs'),
    audio_tracks = self:init_button('audio_tracks'),
    audio_inst = self:init_button('audio_inst'),
    aux = self:init_button('aux'),
    buses = self:init_button('buses'),
    outputs = self:init_button('outputs'),
    user = self:init_button('user'),
    flip = self:init_button('flip'),
    function_ = {
      f1 = self:init_button('function_.f1'), f2 = self:init_button('function_.f2'), f3 = self:init_button('function_.f3'), f4 = self:init_button('function_.f4'),
      f5 = self:init_button('function_.f5'), f6 = self:init_button('function_.f6'), f7 = self:init_button('function_.f7'), f8 = self:init_button('function_.f8')
    },
    modify = {shift = self:init_button('modify.shift'), option = self:init_button('modify.option'), control = self:init_button('modify.control'), alt = self:init_button('modify.alt')},
    automation = {
      read_off = self:init_button('automation.read_off'), write = self:init_button('automation.write'), trim = self:init_button('automation.trim'),
      touch = self:init_button('automation.touch'), latch = self:init_button('automation.latch'), group = self:init_button('automation.group')
    },
    utility = {save = self:init_button('utility.save'), undo = self:init_button('utility.undo'), cancel = self:init_button('utility.cancel'), enter = self:init_button('utility.enter')},
    transport = {
      marker = self:init_button('transport.marker'), nudge = self:init_button('transport.nudge'), cycle = self:init_button('transport.cycle'), drop = self:init_button('transport.drop'),
      replace = self:init_button('transport.replace'), click = self:init_button('transport.click'), solo = self:init_button('transport.solo'), rewind = self:init_button('transport.rewind'),
      forward = self:init_button('transport.forward'), stop = self:init_button('transport.stop'), play = self:init_button('transport.play'), record = self:init_button('transport.record'), jog_wheel = 0
    },
    bank = {left = self:init_button('bank.left'), right = self:init_button('bank.right')},
    channel = {left = self:init_button('channel.left'), right = self:init_button('channel.right')},
    left = self:init_button('left'),
    up = self:init_button('up'),
    down = self:init_button('down'),
    right = self:init_button('right'),
    zoom = self:init_button('zoom'),
    scrub = self:init_button('scrub'),
    lcd = {
      assignment = {left = 0, right = 0},
      bars_hours = {left = 0, middle = 0, right = 0},
      beats_minutes = {left = 0, right = 0},
      subdiv_seconds = {left = 0, right = 0},
      ticks_frames = {left = 0, middle = 0, right = 0}
    },
    tracks = {
      main = {
        fader = self:init_fader('main')
      },
      _1 = {
        screen = {color = {0, 255, 255}, line1 = 'Hello', line2 = 'Renoise', inverse = true},
        rec = self:init_button('channels.1.rec'),
        solo = self:init_button('channels.1.solo'),
        mute = self:init_button('channels.1.mute'),
        select = self:init_button('channels.1.select'),
        vu = 0,
        fader = self:init_fader(1),
        encoder = self:init_encoder(1)
      },
      _2 = {
        screen = {color = {0, 255, 0}, line1 = 'X-Touch', line2 = ' (XCtl)', inverse = true},
        rec = self:init_button('channels.2.rec'),
        solo = self:init_button('channels.2.solo'),
        mute = self:init_button('channels.2.mute'),
        select = self:init_button('channels.2.select'),
        vu = 0,
        fader = self:init_fader(2),
        encoder = self:init_encoder(2)
      },
      _3 = {
        screen = {color = {255, 255, 255}, line1 = 'Support', line2 = 'by bl0b', inverse = false},
        rec = self:init_button('channels.3.rec'),
        solo = self:init_button('channels.3.solo'),
        mute = self:init_button('channels.3.mute'),
        select = self:init_button('channels.3.select'),
        vu = 0,
        fader = self:init_fader(3),
        encoder = self:init_encoder(3)
      },
      _4 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = self:init_button('channels.4.rec'),
        solo = self:init_button('channels.4.solo'),
        mute = self:init_button('channels.4.mute'),
        select = self:init_button('channels.4.select'),
        vu = 0,
        fader = self:init_fader(4),
        encoder = self:init_encoder(4)
      },
      _5 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = self:init_button('channels.5.rec'),
        solo = self:init_button('channels.5.solo'),
        mute = self:init_button('channels.5.mute'),
        select = self:init_button('channels.5.select'),
        vu = 0,
        fader = self:init_fader(5),
        encoder = self:init_encoder(5)
      },
      _6 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = self:init_button('channels.6.rec'),
        solo = self:init_button('channels.6.solo'),
        mute = self:init_button('channels.6.mute'),
        select = self:init_button('channels.6.select'),
        vu = 0,
        fader = self:init_fader(6),
        encoder = self:init_encoder(6)
      },
      _7 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = self:init_button('channels.7.rec'),
        solo = self:init_button('channels.7.solo'),
        mute = self:init_button('channels.7.mute'),
        select = self:init_button('channels.7.select'),
        vu = 0,
        fader = self:init_fader(7),
        encoder = self:init_encoder(7)
      },
      _8 = {
        screen = {color = {0, 0, 0}, line1 = '', line2 = '', inverse = false},
        rec = self:init_button('channels.8.rec'),
        solo = self:init_button('channels.8.solo'),
        mute = self:init_button('channels.8.mute'),
        select = self:init_button('channels.8.select'),
        vu = 0,
        fader = self:init_fader(8),
        encoder = self:init_encoder(8)
      }
    },
    _program_ = {
      number = 0,
      name = 'no program',
      state = renoise.Document.DocumentNode()
    },
    smpte_led = 0,
    beats_led = 0,
    solo_led = 0
  }

  self.channels = {
    main = self.tracks.main,
    [1] = self.tracks._1, [2] = self.tracks._2, [3] = self.tracks._3, [4] = self.tracks._4, [5] = self.tracks._5, [6] = self.tracks._6, [7] = self.tracks._7, [8] = self.tracks._8,
    ['1'] = self.tracks._1, ['2'] = self.tracks._2, ['3'] = self.tracks._3, ['4'] = self.tracks._4, ['5'] = self.tracks._5, ['6'] = self.tracks._6, ['7'] = self.tracks._7, ['8'] = self.tracks._8
  }

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

  self.channels.main.fader.value:add_notifier(self:_fader(9))

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

    ['A'] = 0x5f, ['B'] = 0x7c, ['C'] = 0x58, ['D'] = 0x5e, ['E'] = 0x7c, ['F'] = 0x71, ['G'] = 0x6f, ['H'] = 0x74, ['I'] = 0x04, ['J'] = 0x0c, ['K'] = 0x76, ['L'] = 0x30, ['M'] = 0x37,
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
    self.tracks._7.select.state, self.tracks._8.select.state, self.tracks._1.encoder.state, self.tracks._2.encoder.state, self.tracks._3.encoder.state,
  -- 35
    self.tracks._4.encoder.state, self.tracks._5.encoder.state, self.tracks._6.encoder.state, self.tracks._7.encoder.state, self.tracks._8.encoder.state,
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
    self.tracks._7.fader.state, self.tracks._8.fader.state, self.channels.main.fader.state, nil, nil,
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
    self.zoom.led, self.scrub.led, nil, nil, nil,
  -- 105
    nil, nil, nil, nil, nil,
  -- 110
    nil, nil, nil, self.smpte_led, self.beats_led,
  -- 115
    self.solo_led
  }
  
  for i, obs in pairs(led_map) do
    if obs ~= nil then
      obs:add_notifier(self:_led(obs, i - 1))
    end
  end

  self.fader_origin_xtouch = {false, false, false, false, false, false, false, false, false}
end
