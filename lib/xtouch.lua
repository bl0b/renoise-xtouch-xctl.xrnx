-- 20171110 bl0b
-- based on great documentation by FK http://www.budgetfeatures.com/XctlDOC/Xctl%20Protocol%20for%20X-Touch%20V1.0.pdf
require 'lib/lib'

-- Reload the script whenever this file is saved. 
-- Additionally, execute the attached function.
_AUTO_RELOAD_DEBUG = function()
  print('Reloaded X-Touch tool.')
end

local tool = renoise.tool()
local state_filename = os.currentdir() .. '/XTouch.state'


class "XTouch" (renoise.Document.DocumentNode)


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



local Value = renoise.Document.ObservableNumber
local State = renoise.Document.ObservableBoolean



function XTouch:init_fader(channel)
  local ret = {
    path = 'channels.' .. channel .. '.fader',
    state = State(false),
    value = Value(.75)
  }
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
  return ret
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

  ret.state:add_notifier(function()
    --print("button state", ret.state.value, ret.path)
    if ret.state.value then
      self:trigger('button', 'press', ret)
      --print("long_press_ms", self.long_press_ms)
      tool:add_timer(long, self.long_press_ms * 1.)  -- weird complaint about how it's not a double. so just ensure it is.
    else
      self:trigger('button', 'release', ret)
      if tool:has_timer(long) then
        tool:remove_timer(long)
      end
    end
  end)

  self.hooks[ret.path.value] = {press = {}, release = {}, long_press = {}, any = {}}
end


function XTouch:post_init_fader(ret)
  --print('post_init_fader', ret.path)
  ret.state:add_notifier(function()
    --print('fader', ret.state, ret.value)
    self:trigger('fader', ret.state.value and 'touch' or 'release', ret)
  end)
  ret.value:add_notifier(function() self:trigger('fader', 'move', ret) end)
  self.hooks[ret.path.value] = {touch = {}, release = {}, move = {}, any = {}}
end


function XTouch:post_init_encoder(ret)
  --print(ret.path)
  --ret.path = 'channels.' .. ret.path.value .. '.encoder' -- FIXME
  ret.state:add_notifier(function()
    self:trigger('encoder', ret.state.value and 'press' or 'release', ret)
  end)
  ret.delta:add_notifier(function()
    --print(ret.path)
    self:trigger('encoder', 'delta', ret)
  end)
  self.hooks[ret.path.value] = {press = {}, release = {}, delta = {}, any = {}}
end



function XTouch:get_hooks(event, path)
  return self.hooks[path][event]
end


function XTouch:run_hooks(event, path, real_event, widget)
  --print("callbacks for", event, path, widget.path)
  for _, callback in pairs(self:get_hooks(event, path)) do
    --print(type(callback))
    if callback(real_event, widget) then
      return true
    end
  end
  return false
end



function XTouch:trigger(category, event, widget)
  local general = 'any_' .. category
  local done = false
  if category ~= 'jog_wheel' then
    done = self:run_hooks('any', general, event, widget)
    if not done then
      done = self:run_hooks(event, general, event, widget)
    end
    if not done then
      done = self:run_hooks('any', widget.path.value, event, widget)
    end
  end
  if not done then
    done = self:run_hooks(event, widget.path.value, event, widget)
  end
end
--  local any = {}
--  print("trigger", category, event, widget.path)
--  if category == 'encoder' then
--    any = self.any_encoder
--  elseif category == 'fader' then
--    any = self.any_fader
--  elseif category == 'button' then
--    any = self.any_button
--  end
--  local done = false
--  print("ANY… callbacks", done)
--  for _, callback in pairs(any) do
--    print("any callback", widget.name)
--    done = callback(event, widget)
--    if done then
--      break
--    end
--  end
--  print(widget.path, "callbacks", done)
--  if not done then
--    local hooks = self.hooks[widget.path]
--    print('hooks')
--    rprint(hooks)
--    if hooks ~= nil then
--      local stack = hooks[event]
--      print('stack')
--      rprint(stack)
--      if stack ~= nil then
--        for _, callback in pairs(stack) do
--          print("specific callback", widget.name)
--          if callback(event, widget) then
--            break
--          end
--        end
--      end
--    end
--  end
--end


function XTouch:on(where, when, how)
  local path = where.path ~= nil and where.path.value or where
  print("ON '" .. path .. "' type=" .. type(path))
  if self.hooks[path] == nil then
    print(path, 'not found')
    local keys = ''
    for k, _ in pairs(self.hooks) do
      keys = keys .. ',' .. k.value
    end
    print("have keys", keys)
    return
  end
  local hooks = self.hooks[path]
  if hooks[when] == nil then
    print('event', when, 'not found')
    return
  end
  local stack = hooks[when]
  table.insert(stack, how)
end


function XTouch:off(where, when)
  table.remove(self.hooks[where.path.value or where][when])
end


require 'lib/program_manager'


-- Controller class Ctor
function XTouch:__init(options)
  local button_auto_led = {press = 2, release = 0, long_press = 1}
  print("CTOR XTouch")
  self.in_name = options.input_device.value
  self.out_name = options.output_device.value
  self.long_press_ms = options.long_press_ms.value
  self.hooks = {
    any_button = {
      any = {
        function(event, widget)
          print("ANY BUTTON!", event, widget.path)
          widget.led.value = button_auto_led[event]
          return false
        end
      },
      press = {},
      long_press = {},
      release = {}
    },
    
    any_fader = {
      any = {},
      touch = {},
      release = {},
      move = {}
    },
    
    any_encoder = {
      any = {},
      press = {},
      release = {},
      delta = {}
    }
  }
  
  self.post_init_widgets = {}
  
  renoise.Document.DocumentNode.__init(self)
  
  self:open()
  
  self:init_annoyingly_big_data()

  self.transport.jog_wheel.delta:add_notifier(function() if self.transport.jog_wheel.delta.value ~= 0 then self:trigger('jog_wheel', 'delta', self.transport.jog_wheel) end end)
  self.hooks['transport.jog_wheel'] = {delta = {}}

  self:load_state()
  
  local out = function(msg) self:send(msg) end

  self.ping_func = function() self:ping() end
  self.ping_period = options.ping_period.value
  --print("SELF.PING_PERIOD =", ping_period)
  renoise.tool():add_timer({self, self.ping}, self.ping_period)
  self.pong = true
  self.is_alive = false
  self:ping()

  for _, data in pairs(self.post_init_widgets) do
    --print('post_init', data[1])
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
      --print('post_init_encoder', data[1], el.path.value)
      self:post_init_encoder(el)
    end
  end

  self.vu_hack = {}
  local tracks = renoise.song().tracks
  for i = 1, math.min(#tracks, 8) do
    self:attach_VU_to_track(i, i)
  end
  --rprint(self.hooks)

  self:init_program_manager()
end



function XTouch:send_lcd_string(start_digit, str)
  print("send_lcd_digits")
  local stop = math.min(13 - start_digit, string.len(str))
  for i = 1, stop do
    local c = self.lcd_ascii[string.sub(str, i, i)]
    if c ~= nil then
      print(start_digit, self.lcd_digits[start_digit])
      self.lcd_digits[start_digit].value = c
      start_digit = start_digit + 1
    end
  end
  while start_digit <= 12 do
    self.lcd_digits[start_digit].value = 0
    start_digit = start_digit + 1
  end
end



require 'lib/midi'

require 'lib/vu_hack'

require 'lib/init_long_data'