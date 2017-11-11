-- 20171110 bl0b
-- First attempt at a script.

class "XTouch"


-- Match a color to one in the X-Touch
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
    local msg = {0xf0, 0, 0, 0x66, 0x58, 0x20 + channel, match_color(screen.color[1], screen.color[2], screen.color[3]), 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0xf7}
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
    print("send fader ", value, bit.band(value, 0x7f), bit.rshift(value, 7))
    out({pb, bit.band(value, 0x7f), bit.rshift(value, 7)})
  end
end


-- send message for LEDs
-- (channel) -> (outfunc, value) -> nil
function send_led(number)
  return function(out, value)
    print("send led ", value)
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
    main_fader = send_fader(8),
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

local note_map = {
-- 0
 'rec_1',
 'rec_2',
 'rec_3',
 'rec_4',
 'rec_5',
-- 5
 'rec_6',
 'rec_7',
 'rec_8',
 'solo_1',
 'solo_2',
-- 10
 'solo_3',
 'solo_4',
 'solo_5',
 'solo_6',
 'solo_7',
-- 15
 'solo_8',
 'mute_1',
 'mute_2',
 'mute_3',
 'mute_4',
-- 20
 'mute_5',
 'mute_6',
 'mute_7',
 'mute_8',
 'select_1',
-- 25
 'select_2',
 'select_3',
 'select_4',
 'select_5',
 'select_6',
-- 30
 'select_7',
 'select_8',
 'encoder_push_1',
 'encoder_push_2',
 'encoder_push_3',
-- 35
 'encoder_push_4',
 'encoder_push_5',
 'encoder_push_6',
 'encoder_push_7',
 'encoder_push_8',
-- 40
 'enc_assign_track',
 'enc_assign_send',
 'enc_assign_pan',
 'enc_assign_plugin',
 'enc_assign_eq',
-- 45
 'enc_assign_inst',
 'fader_bank_left',
 'fader_bank_right',
 'channel_left',
 'channel_right',
-- 50
 'flip',
 'global_view',
 'display',
 'smpte_beats',
 'f1',
-- 55
 'f2',
 'f3',
 'f4',
 'f5',
 'f6',
-- 60
 'f7',
 'f8',
 'midi_tracks',
 'inputs',
 'audio_tracks',
-- 65
 'audio_inst',
 'aux',
 'buses',
 'outputs',
 'user',
-- 70
 'shift',
 'option',
 'control',
 'alt',
 'read_off',
-- 75
 'write',
 'trim',
 'touch',
 'latch',
 'group',
-- 80
 'save',
 'undo',
 'cancel',
 'enter',
 'marker',
-- 85
 'nudge',
 'cycle',
 'drop',
 'replace',
 'click',
-- 90
 'solo',
 'transport_rewind',
 'transport_forward',
 'transport_stop',
 'transport_play',
-- 95,
 'transport_record',
 'up',
 'down',
 'left',
 'right',
-- 100
 'zoom',
 'scrub',
 nil,
 nil,
 'fader_touch_1',
-- 105
 'fader_touch_2',
 'fader_touch_3',
 'fader_touch_4',
 'fader_touch_5',
 'fader_touch_6',
-- 110
 'fader_touch_7',
 'fader_touch_8',
 'fader_toouch_9',
 nil,
 nil,
-- 115
 'solo', 
 nil, 
 nil, 
 nil,
 nil,
-- 120
 nil, 
 nil, 
 nil, 
 nil,
 nil,
-- 125
 nil, 
 nil, 
 nil
}


-- Find what settings change and how to send these changes by simple pattern matching
-- (out, new_partial_status, current_status, message_methods) -> nil (side effects: messages sent and current_status is updated)

function find_changes(out, new_partial_status, current_status, message_methods)
  print("Entering find_changes…")
  rprint(new_partial_status)
  for k, v in pairs(new_partial_status) do
    print("On key ", k)
    if type(message_methods[k]) == 'table' then
      print("… is a table!")
      rprint(v)
      current_status[k] = current_status[k] or {}
      find_changes(out, v, current_status[k], message_methods[k])
    else
      print("  value is ", v)
      if v ~= current_status[k] then
        print("Updating status…")
        current_status[k] = v
        message_methods[k](out, v)
      end
    end
  end
  print("Exiting find_changes…")
end


-- Controller class Ctor
function XTouch:__init(midiin, midiout)
  print("CTOR XTouch")
  oprint(midiin)
  self.input = renoise.Midi.create_input_device(midiin, function (msg) self:parse_msg(msg) end, function (msg) self:parse_msg(msg) end)
  self.output = renoise.Midi.create_output_device(midiout)
  self.output:send({0xf0, 0x00, 0x00, 0x66, 0x58, 0x01, 0x30, 0x31, 0x35, 0x36, 0x34, 0x30, 0x33, 0x35, 0x39, 0x32, 0x41, 0xf7})
  self.status = {}
  local status = {
    encoder_leds = {0, 0, 0, 0, 0, 0, 0, 0},
    tracks = {
      {screen = {color = {0, 255, 0}, lines = {'Hello', 'Renoise'}}, rec = 0, solo = 0, mute = 0, select = 0, vu = 0., fader = 0.},
      {screen = {color = {0, 255, 255}, lines = {'X-Touch', '(XCtl)'}}, rec = 0, solo = 0, mute = 0, select = 0, vu = 0., fader = 0.},
      {screen = {color = {255, 255, 255}, lines = {'Support', 'by bl0b'}}, rec = 0, solo = 0, mute = 0, select = 0, vu = 0., fader = 0.},
      {screen = {color = {0, 0, 0}, lines = {'', ''}}, rec = 0, solo = 0, mute = 0, select = 0, vu = 0., fader = 0.},
      {screen = {color = {0, 0, 0}, lines = {'', ''}}, rec = 0, solo = 0, mute = 0, select = 0, vu = 0., fader = 0.},
      {screen = {color = {0, 0, 0}, lines = {'', ''}}, rec = 0, solo = 0, mute = 0, select = 0, vu = 0., fader = 0.},
      {screen = {color = {0, 0, 0}, lines = {'', ''}}, rec = 0, solo = 0, mute = 0, select = 0, vu = 0., fader = 0.},
      {screen = {color = {0, 0, 0}, lines = {'', ''}}, rec = 0, solo = 0, mute = 0, select = 0, vu = 0., fader = 0.}
    },
    main_fader = .75,
    encoder_assign = {
      track = 0,
      pan = 0,
      eq = 0,
      send = 0,
      plugin = 0,
      inst = 0
    },
    display_name_or_value = 0,
    global_view = 0,
    midi_tracks = 0,
    inputs = 0,
    audio_tracks = 0,
    aux = 0,
    buses = 0,
    outputs = 0,
    user = 0,
    flip = 0,
    f1 = 0,
    f2 = 0,
    f3 = 0,
    f4 = 0,
    f5 = 0,
    f6 = 0,
    f7 = 0,
    f8 = 0,
    shift = 0,
    option = 0,
    read_off = 0,
    write = 0,
    trim = 0,
    save = 0,
    undo = 0,
    control = 0,
    alt = 0,
    touch = 0,
    latch = 0,
    group = 0,
    cancel = 0,
    enter = 0,
    marker = 0,
    nudge = 0,
    cycle = 0,
    drop = 0,
    replace = 0,
    click = 0,
    solo = 0,
    transport_rewind = 0,
    transport_forward = 0,
    transport_stop = 0,
    transport_play = 0,
    transport_record = 0,
    bank_left = 0,
    bank_right = 0,
    channel_left = 0,
    channel_right = 0,
    left = 0,
    up = 0,
    down = 0,
    right = 0,
    zoom = 0,
    scrub = 0,
  }
  
  renoise.tool():add_timer(function() self:ping() end, 6000)
  self:update(self.status, true)
  self:ping()
  local out = function(msg)
    print_msg('Sending', msg)
    self.output:send(msg)
  end
  self:update(status)
--  for i = 0, 7 do
--    local t = renoise.song().tracks[i + 1]
--    if t ~= nil then
--      self.status.tracks[i + 1].screen.color = match_color(t.color[1], t.color[2], t.color[3])
--    else
--      self.status.tracks[i + 1].screen.color = 0
--    end
--    send_screen(i)(out, self.status.tracks[i + 1].screen)
--    send_fader(i)(out, .75)
--    send_enc_led(i)(out, (i + 1) * 1024 - 1)
--    send_vu(i)(out, .15 * i)
----    send_vu2(i)(out, .15 * i)
--  end
--  send_led(50)(out, 1)
end


function XTouch:ping()
  print_msg('Ping', {0xf0, 0, 0, 0x66, 0x14, 0, 0xf7})
  self.output:send({0xf0, 0, 0, 0x66, 0x14, 0, 0xf7})
end


function XTouch:parse_msg(msg)
  local cmd = bit.rshift(msg[1], 4)
  local chan = bit.band(msg[1], 0xF)
  if cmd == 0x9 or cmd == 0x8 then
    local label = note_map[msg[2] + 1]
    local pressed = (cmd == 0x9 and msg[3] > 0)
    print("cmd ", cmd, " vel ", msg[3], " pressed ", pressed)
    if pressed then
      print("A button was pressed! " .. label)
    else
      print("A button was released! " .. label)
    end
  elseif cmd == 0xB then
    print("0xB")
  elseif cmd == 0xC then
    print("control change")
  elseif cmd == 0xD then
    print("0xD")
  elseif cmd == 0xE then
    print("0xE")
  else
    print_msg('Received', msg)
  end
end


function XTouch:update(partial_status)
  local out = function(msg)
    print_msg('Updating', msg)
    self.output:send(msg)
  end
  find_changes(out, partial_status, self.status, message_types)
end
