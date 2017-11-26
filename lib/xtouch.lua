-- 20171110 bl0b
-- based on great documentation by FK http://www.budgetfeatures.com/XctlDOC/Xctl%20Protocol%20for%20X-Touch%20V1.0.pdf
require 'lib/lib'
require 'lib/program_manager'

-- Reload the script whenever this file is saved. 
-- Additionally, execute the attached function.
_AUTO_RELOAD_DEBUG = function()
  print('Reloaded X-Touch tool.')
end

local tool = renoise.tool()
local state_filename = os.currentdir() .. '/XTouch.state'


class "XTouch" (renoise.Document.DocumentNode, ProgramManager)


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


local Value = renoise.Document.ObservableNumber
local State = renoise.Document.ObservableBoolean



function XTouch:init_fader(channel)
  local ret = {
    path = 'channels.' .. channel .. '.fader',
    state = State(false),
    value = Value(.75)
  }
  print('new fader')
  rprint(ret)
  table.insert(self.post_init_widgets, {ret.path, 'fader'})
  return ret
end


function XTouch:init_button(name)
  local ret = {
    path = name,
    state = State(false),
    led = Value(0)
  }
  table.insert(self.post_init_widgets, {ret.path, 'button'})
  return ret
end


function XTouch:init_encoder(channel)
  local ret = {
    path = 'channels.' .. channel .. '.encoder',
    state = State(false),
    delta = Value(0),
    led = Value(0)
  }
  table.insert(self.post_init_widgets, {ret.path, 'encoder'})
  --print("ENCODER")
  rprint(ret)
  return ret
end


function XTouch:trigger(category, event, widget)
  local any = {}
  print("trigger", category, event, widget.path)
  if category == 'encoder' then
    any = self.any_encoder
  elseif category == 'fader' then
    any = self.any_fader
  elseif category == 'button' then
    any = self.any_button
  end
  for _, callback in pairs(any) do
    callback(event, widget)
  end
end


-- The notion of click and double-click is prohibited on a live control surface. A long press works fine.
function XTouch:post_init_button(ret)
  local long
  long = function()
    --print('running long_press…')
    if tool:has_timer(long) then
      tool:remove_timer(long)
      self:trigger('button', 'long_press', ret)
    end
  end

  ret.state:add_notifier((function(long) return function()
    --print("button state", ret.state.value, ret.path)
    if ret.state.value then
      self:trigger('button', 'press', ret)
      --print("long_press_ms", self.long_press_ms)
      tool:add_timer(long, self.long_press_ms * 1.)
    else
      self:trigger('button', 'release', ret)
      if tool:has_timer(long) then
        tool:remove_timer(long)
      end
    end
  end end)(long))
end


function XTouch:post_init_fader(ret)
  print('post_init_fader', ret.path)
  ret.state:add_notifier(function()
    print('fader', ret.state, ret.value)
    self:trigger('fader', ret.state.value and 'touching' or 'released', ret)
  end)
  ret.value:add_notifier(function() self:trigger('fader', 'moved', ret) end)
end


function XTouch:post_init_encoder(ret)
  print(ret.path)
  --ret.path = 'channels.' .. ret.path.value .. '.encoder' -- FIXME
  ret.state:add_notifier(function()
    self:trigger('encoder', ret.state.value and 'press' or 'release', ret)
  end)
  ret.delta:add_notifier(function()
    print(ret.path)
    self:trigger('encoder', 'delta', ret)
  end)
end


-- Controller class Ctor
function XTouch:__init(midiin, midiout, ping_period, long_press_ms)
  print("CTOR XTouch")
  self.in_name = midiin
  self.out_name = midiout
  self.long_press_ms = long_press_ms
  self:open()
  -- important! call super first
  --oprint(self.output) rprint(self.output)
  self.closed = false
  renoise.Document.DocumentNode.__init(self)
  --self.output:send({0xf0, 0x00, 0x00, 0x66, 0x58, 0x01, 0x30, 0x31, 0x35, 0x36, 0x34, 0x30, 0x33, 0x35, 0x39, 0x32, 0x41, 0xf7})
  
  self.hooks = {}
  local button_auto_led = {press = 2, release = 0, long_press = 1}
  self.any_button = {function(event, widget) print("ANY BUTTON!", event, widget.path) widget.led.value = button_auto_led[event] end}
  self.any_fader = {}
  self.any_encoder = {}
  
  self.post_init_widgets = {}
  
  self:init_annoyingly_big_data()
  
  --oprint(self)

  local out = function(msg) self:send(msg) end

  --send_screen(0)(out, self.tracks._1.screen)

  
  self.ping_func = function() self:ping() end
  self.ping_period = ping_period
  --print("SELF.PING_PERIOD =", ping_period)
  renoise.tool():add_timer({self, self.ping}, ping_period)
  self.pong = true
  self.is_alive = false
  self:ping()

--  self.channels[1].encoder.led.value = 0x2AA
--  self.flip.state:add_notifier(function()
--    if self.flip.state.value == 0 then
--      return
--    end
--    if self.flip.led.value == 2 then
--      self.flip.led.value = 0
--      self:send_lcd_string(1, "hello world!")
--    elseif self.flip.led.value == 1 then
--      self.flip.led.value = self.flip.led.value + 1
--      self:send_lcd_string(1, '=0123456789=')
--    else
--      self.flip.led.value = self.flip.led.value + 1
--      self:send_lcd_string(1, "X-touch bl0b")
--    end
--  end)

  for _, data in pairs(self.post_init_widgets) do
    print('post_init', data[1])
    local el, name, last
    el, name, last  = find_element(self, data[1])
    if el == nil then
      error("couldn't find element " .. data[1])
    end
    if data[2] == 'button' then
      self:post_init_button(el)
    elseif data[2] == 'fader' then
      self:post_init_fader(el)
    elseif data[2] == 'encoder' then
      print('post_init_encoder', data[1], el.path.value)
      self:post_init_encoder(el)
    end
  end

  ProgramManager.__init(self)
  self:load_state()

  self.vu_hack = {}
  local tracks = renoise.song().tracks
  for i = 1, math.min(#tracks, 8) do
    self:attach_VU_to_track(i, i)
  end
end


function XTouch:select_program(program_number)
  if self._program_.number > 0 then
    self.programs[self._program_.number].terminate(self, self._program_.state)
  end
  self._program_.number = program_number
  local prg = self.programs[self._program_.number]
  self._program_.state = renoise.Document.DocumentNode()
  self._program_.state:add_properties(prg.state)
  prg.init(self, self._program_.state)
end


require 'lib/midi'

require 'lib/vu_hack'

require 'lib/init_long_data'