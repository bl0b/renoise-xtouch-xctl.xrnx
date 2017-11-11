-- 20171110 bl0b
-- First attempt at a script.

class "XTouch"

-- dump a midi message in the terminal
-- (prefix, message) -> nil
function print_msg(s, msg)
  for i = 1, #msg do
    s = s .. ' ' .. string.format('%02x', msg[i] or 0)
  end
  print(s)
end


-- send message for encoder LEDs
-- (channel) -> (outfunc, value) -> nil
function send_enc_led(channel)
  local cc1 = 48 + channel
  local cc2 = 56 + channel
  return function (out, value)
    out({0xb0, cc1, bit.rshift(value, 6)})
    out({0xb0, cc2, bit.band(value, 0x3f)})
  end
end


-- send message for vu meter
-- (channel) -> (outfunc, value) -> nil
function send_vu(channel)
  channel = channel * 16
  return function(out, value)
    value = 8 * value
    if value > 15 then value = 15 end
    out({0xd0, channel + value})
  end
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
    --table.insert(ret, 0)
    msg[ofs + i] = 0
  end
  --return ret[1], ret[2], ret[3], ret[4], ret[5], ret[6], ret[7]
end


-- send message for screens
-- (channel) -> (outfunc, screen table) -> nil
function send_screen(channel)
  return function (out, screen)
    local msg = {0xf0, 0, 0, 0x66, 0x58, 0x20 + channel, screen.color, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0xf7}
    str2arr(screen.lines[1], msg, 1)
    str2arr(screen.lines[2], msg, 2)
    out(msg)
  end
end


-- send message for faders
-- (channel) -> (outfunc, value) -> nil
function send_fader(channel)
  local pb = 0xe0 + channel
  return function(out, value)
    value = math.floor(16384 * value)
    out({pb, bit.band(value, 0x7f), bit.rshift(value, 7)})
  end
end


-- send message for LEDs
-- (channel) -> (outfunc, value) -> nil
function send_led(number)
  return function(out, value)
    out({0x90, number, value})
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


--describe how to send what.
local message_types = {
    encoder_leds = {send_enc_led(0), send_enc_led(1), send_enc_led(2), send_enc_led(3),
                    send_enc_led(4), send_enc_led(5), send_enc_led(6), send_enc_led(7)},
    tracks = {
      send_track(0), send_track(1), send_track(2), send_track(3),
      send_track(4), send_track(5), send_track(6), send_track(7)
    },
    main_fader = 0,
    encoder_assign = {
      track = send_led(40),
      pan = send_led(42),
      eq = send_led(44),
      send = send_led(41),
      plugin = send_led(43),
      inst = send_led(45)
    },
    display_name_or_value = send_led(52),
    global_view = send_led(51),
    midi_tracks = send_led(62),
    inputs = send_led(63),
    audio_tracks = send_led(64),
    aux = send_led(66),
    buses = send_led(67),
    outputs = send_led(68),
    user = send_led(69),
    flip = send_led(50),
    f1 = send_led(54),
    f2 = send_led(55),
    f3 = send_led(56),
    f4 = send_led(57),
    f5 = send_led(58),
    f6 = send_led(59),
    f7 = send_led(60),
    f8 = send_led(61),
    shift = send_led(70),
    option = send_led(71),
    read_off = send_led(74),
    write = send_led(75),
    trim = send_led(76),
    save = send_led(80),
    undo = send_led(81),
    control = send_led(72),
    alt = send_led(73),
    touch = send_led(77),
    latch = send_led(78),
    group = send_led(79),
    cancel = send_led(82),
    enter = send_led(83),
    marker = send_led(84),
    nudge = send_led(85),
    cycle = send_led(86),
    drop = send_led(87),
    replace = send_led(88),
    click = send_led(89),
    solo = send_led(90),
    transport_rewind = send_led(91),
    transport_forward = send_led(92),
    transport_stop = send_led(93),
    transport_play = send_led(94),
    transport_record = send_led(95),
    bank_left = send_led(46),
    bank_right = send_led(47),
    channel_left = send_led(48),
    channel_right = send_led(49),
    left = send_led(98),
    up = send_led(96),
    down = send_led(97),
    right = send_led(99),
    zoom = send_led(100),
    scrub = send_led(101),
  }


-- Match Renoise color to one in the X-Touch
-- X-Touch defines:
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


function XTouch:__init(midiin, midiout)
  print("CTOR XTouch")
  oprint(midiin)
  self.input = renoise.Midi.create_input_device(midiin, function (msg) self:parse_msg(msg) end, function (msg) self:parse_msg(msg) end)
  self.output = renoise.Midi.create_output_device(midiout)
  self.output:send({0xf0, 0x00, 0x00, 0x66, 0x58, 0x01, 0x30, 0x31, 0x35, 0x36, 0x34, 0x30, 0x33, 0x35, 0x39, 0x32, 0x41, 0xf7})
  self.status = {
    encoder_leds = {0, 0, 0, 0, 0, 0, 0, 0},
    tracks = {
      {screen = {color = 0x41, lines = {'Hi', 'Renoise'}}, rec = false, solo = false, mute = false, select = false, vu = 0., fader = 0.},
      {screen = {color = 0x42, lines = {'Hello', 'Renoise'}}, rec = false, solo = false, mute = false, select = false, vu = 0., fader = 0.},
      {screen = {color = 0x43, lines = {'Hi', 'Renoise'}}, rec = false, solo = false, mute = false, select = false, vu = 0., fader = 0.},
      {screen = {color = 0x44, lines = {'Hello', 'Renoise'}}, rec = false, solo = false, mute = false, select = false, vu = 0., fader = 0.},
      {screen = {color = 0x45, lines = {'Hi', 'Renoise'}}, rec = false, solo = false, mute = false, select = false, vu = 0., fader = 0.},
      {screen = {color = 0x46, lines = {'Hello', 'Renoise'}}, rec = false, solo = false, mute = false, select = false, vu = 0., fader = 0.},
      {screen = {color = 0x47, lines = {'Hi', 'Renoise'}}, rec = false, solo = false, mute = false, select = false, vu = 0., fader = 0.},
      {screen = {color = 0x48, lines = {'Hello', 'Renoise'}}, rec = false, solo = false, mute = false, select = false, vu = 0., fader = 0.}
    },
    main_fader = 0,
    encoder_assign = {
      track = false,
      pan = false,
      eq = false,
      send = false,
      plugin = false,
      inst = false
    },
    display_name_or_value = false,
    global_view = false,
    midi_tracks = false,
    inputs = false,
    audio_tracks = false,
    aux = false,
    buses = false,
    outputs = false,
    user = false,
    flip = false,
    f1 = false,
    f2 = false,
    f3 = false,
    f4 = false,
    f5 = false,
    f6 = false,
    f7 = false,
    f8 = false,
    shift = false,
    option = false,
    read_off = false,
    write = false,
    trim = false,
    save = false,
    undo = false,
    control = false,
    alt = false,
    touch = false,
    latch = false,
    group = false,
    cancel = false,
    enter = false,
    marker = false,
    nudge = false,
    cycle = false,
    drop = false,
    replace = false,
    click = false,
    solo = false,
    transport_rewind = false,
    transport_forward = false,
    transport_stop = false,
    transport_play = false,
    transport_record = false,
    bank_left = false,
    bank_right = false,
    channel_left = false,
    channel_right = false,
    left = false,
    up = false,
    down = false,
    right = false,
    zoom = false,
    scrub = false,
  }
  
  renoise.tool():add_timer(function() self:ping() end, 6000)
  self:update(self.status, true)
  self:ping()
  local out = function(msg)
    print_msg('Sending', msg)
    self.output:send(msg)
  end
  for i = 0, 7 do
    local t = renoise.song().tracks[i + 1]
    if t ~= nil then
      self.status.tracks[i + 1].screen.color = match_color(t.color[1], t.color[2], t.color[3])
    else
      self.status.tracks[i + 1].screen.color = 0
    end
    send_screen(i)(out, self.status.tracks[i + 1].screen)
    send_fader(i)(out, .75)
    send_enc_led(i)(out, (i + 1) * 1024 - 1)
    send_vu(i)(out, .15 * i)
--    send_vu2(i)(out, .15 * i)
  end
  send_led(50)(out, 1)
end


function XTouch:ping()
  print_msg('Ping', {0xf0, 0, 0, 0x66, 0x14, 0, 0xf7})
  self.output:send({0xf0, 0, 0, 0x66, 0x14, 0, 0xf7})
end


function XTouch:parse_msg(msg)
  print_msg('Received', msg)
end


function XTouch:update(partial_status)
  for k, v in pairs(partial_status) do
    oprint(k, v)
  end
end
