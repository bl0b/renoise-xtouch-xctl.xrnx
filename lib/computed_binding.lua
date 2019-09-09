class "ComputedBinding"

function ComputedBinding:__init(binding, schema_manager)
  self.binding = binding
  self.schema_manager = schema_manager
  self.xtouch = schema_manager.xtouch
  self.cursor = self.schema_manager:copy_cursor()
  self:init(schema_manager)
end

function ComputedBinding:resolve(what)
  -- print('resolve', what)
  -- rprint(self.cursor)
  return self.schema_manager:eval(what, self.cursor)
end

function ComputedBinding:eval(resolved)
  local widget, event = self.schema_manager:lua_eval(resolved)
  return widget, event
end




class "FaderBinding" (ComputedBinding)

function FaderBinding:__init(b, s)
  ComputedBinding.__init(self, b, s)
  self.context = nil
end

local fader_to_value = function(x)
  return math.db2lin(math.fader2db(-96, 3, x))
end

local value_to_fader = function(x)
  return math.db2fader(-96, 3, math.lin2db(x))
end

function FaderBinding:init()
  self.to_fader = self.binding.to_fader or function(c, s, v) return value_to_fader(v) end
  self.from_fader = self.binding.from_fader or function(c, s, v) return fader_to_value(v) end
  self.context = nil
  self.set_fader = function()
    -- print('set_fader', self:resolve(self.binding.fader), self:resolve(self.binding.value), type(self.with_value), self.context == nil and 'organic' or 'reentrant')
    if self.context == nil then
      self.context = 'r'
      local tmp = self.to_fader(self.cursor, self.schema_manager.state, self.with_value.value)
      if tmp ~= nil and self.widget.value.value ~= tmp then self.widget.value.value = tmp end
      self.context = nil
    end
  end
  self.set_observable = function(event, widget)
    -- print('set_observable', self.context == nil and 'organic' or 'reentrant', type(self.context))
    if self.context == nil then
      self.context = 'x'
      local tmp = self.from_fader(self.cursor, self.schema_manager.state, widget.value.value)
      -- print(tmp, self.with_value.value)
      if tmp ~= nil and self.with_value.value ~= tmp then self.with_value.value = tmp end
      self.context = nil
    end
  end
  self.with_value = nil
  self.fader = nil
end

function FaderBinding:update(mm)
  self.cursor = self.schema_manager:copy_cursor()
  local fader_source = self:resolve(self.binding.fader)
  self.widget = self:eval(fader_source)
  local obs_source = self:resolve(self.binding.obs)
  local obs = self:eval(obs_source)
  self.with_value = self:resolve(self.binding.value)
  local map_to_fader = ObservableMapping(obs_source, obs, self.set_fader, true)
  local map_from_fader = XTouchMapping(fader_source, self.widget, 'move', self.set_observable)
  mm:update_binding(fader_source, map_from_fader)
  mm:update_binding(obs_source, map_to_fader)
end




class "LedBinding" (ComputedBinding)

function LedBinding:__init(b, s)
  ComputedBinding.__init(self, b, s)
end

function LedBinding:init()
  self.cursor = self.schema_manager:copy_cursor()
  self.to_led = self.binding.to_led or function(c, s, x) return x and 2 or 0 end
  self.val = self.binding.value
  self.callback = function(cursor, state)
    -- print("LedBinding", self.source, self.led, self.observable, self.value)
    -- rprint(self.cursor)
    -- print('----------')
    if self.led ~= nil and self.observable ~= nil then
      self.led.value = self.to_led(self.cursor, self.schema_manager.state, self.val(self.cursor, self.schema_manager.state))
    end
  end
  self.led = nil
  self.observable = nil
end

function LedBinding:update(mm)
  self.cursor = self.schema_manager:copy_cursor()
  self.led = self:resolve(self.binding.led)
  local obs_source = self:resolve(self.binding.obs)
  self.observable = self:eval(obs_source)
  mm:update_binding(obs_source, ObservableMapping(obs_source, self.observable, self.callback, true))
end




class "ScreenBinding" (ComputedBinding)

function ScreenBinding:__init(b, s) ComputedBinding.__init(self, b, s) end

function ScreenBinding:init()
  self.callback = function()
    self.binding.render(self.cursor, self.schema_manager.state, self.screen, self.value)
    self.xtouch:send_strip(self.cursor.channel)
  end
end

function ScreenBinding:update(mm)
  self.cursor = self.schema_manager:copy_cursor()
  local trigger_source = self:resolve(self.binding.trigger)
  local trigger = self:eval(trigger_source)
  self.screen = self:resolve(self.binding.screen)
  self.value = self:resolve(self.binding.value)
  self.cursor.channel = 0 + self.screen._channel_.value
  -- print('screen', self.value)
  if self.value ~= nil then
    mm:update_binding('screen#' .. self.screen._channel_.value, ScreenMapping(self.screen))
    mm:update_binding(trigger_source, ObservableMapping(trigger_source, trigger, self.callback, true))
  end
end




class "SimpleBinding" (ComputedBinding)

function SimpleBinding:__init(b, s)
  ComputedBinding.__init(self, b, s)
  local cb = self.callback
end

function SimpleBinding:init()
  if self.binding.xtouch ~= nil then
    self.callback = function(widget, event) self.binding.callback(self.cursor, self.schema_manager.state, widget, event) end
  else
    self.callback = function() self.binding.callback(self.cursor, self.schema_manager.state) end
  end
  self.widget = nil
end

function SimpleBinding:update(mm)
  self.cursor = self.schema_manager:copy_cursor()
  local source = self:resolve(self.binding.renoise or self.binding.xtouch)
  if self.binding.xtouch ~= nil then
    local widget, event = self:eval(source)
    mm:update_binding(source, XTouchMapping(source, widget, event, self.callback))
  else
    mm:update_binding(source, ObservableMapping(source, self:eval(source), self.callback))
  end
end




class "VuBinding" (ComputedBinding)

function VuBinding:__init(b, s)
  ComputedBinding.__init(self, b, s)
end

function VuBinding:init()
end

function VuBinding:update(mm)
  self.cursor = self.schema_manager:copy_cursor()
  local vu = self:resolve(self.binding.vu)
  local at = self:resolve(self.binding.at)
  local track = self:resolve(self.binding.track)
  local post = self:resolve(self.binding.post)
  -- print('VuBinding', vu, at, track, post)
  if vu ~= nil and track ~= nil and post ~= nil then
    mm:update_binding('VU#' .. vu, VuMapping(vu, track, at, post))
  end
end
-- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == --
