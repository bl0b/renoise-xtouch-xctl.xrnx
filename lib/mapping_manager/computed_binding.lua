class "ComputedBinding"

function ComputedBinding:__init(binding, schema_manager, suffix)
  self.binding = binding
  self.schema_manager = schema_manager
  self.xtouch = schema_manager.xtouch
  self.suffix = suffix or ''
  self.cursor = self.schema_manager:copy_cursor()
  -- print("binding with suffix «" .. self.suffix .. '»')
  self:init(schema_manager)
end

function ComputedBinding:resolve(what)
  -- print('resolve', what)
  -- rprint(self.cursor)
  return self.schema_manager:eval(what, self.cursor)
end

function ComputedBinding:eval(resolved)
  if type(resolved) == 'string' then
    local widget, event = self.schema_manager:lua_eval(resolved, self.cursor)
    return widget, event
  end
  return resolved
end


class "FaderBinding" (ComputedBinding)

function FaderBinding:__init(b, s, x)
  ComputedBinding.__init(self, b, s, x)
  self.context = nil
end

local fader_to_value = function(x)
  return math.db2lin(math.fader2db(-96, 3, x))
end

local value_to_fader = function(x)
  return x and math.db2fader(-96, 3, math.lin2db(x)) or 0
end

function FaderBinding:init()
  self.to_fader = self.binding.to_fader or function(c, s, v) return value_to_fader(v) end
  self.from_fader = self.binding.from_fader or function(c, s, v) return fader_to_value(v) end
  self.set_fader = function()
    if self.widget.state.value then
      return
    end
    -- print('[xtouch] set_fader', self:resolve(self.binding.fader), self:resolve(self.binding.value), type(self.with_value), self.context == nil and 'organic' or 'reentrant')
    local tmp = self.to_fader(self.cursor, self.schema_manager.state, self.with_value and self.with_value.value) or 0
    if self.widget.value.value ~= tmp then self.widget.value.value = tmp end
  end
  self.set_observable = function(event, widget)
    if not self.widget.state.value then
      return
    end
    -- print('set_observable', self.context == nil and 'organic' or 'reentrant', type(self.context))
    if self.with_value == nil then return end
    local tmp = self.from_fader(self.cursor, self.schema_manager.state, widget.value.value)
    -- print(tmp, self.with_value.value)
    if tmp ~= nil and self.with_value.value ~= tmp then self.with_value.value = tmp end
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
  self.with_value = self:eval(self:resolve(self.binding.value))
  if self.widget then
    local map_from_fader = XTouchMapping(fader_source, self.widget, 'move', self.set_observable)
    mm:update_binding(fader_source .. self.suffix, map_from_fader)
  end
  if obs then
    local map_to_fader = ObservableMapping(obs_source, obs, self.set_fader, true)
    mm:update_binding(obs_source .. self.suffix, map_to_fader)
  end
end




class "LedBinding" (ComputedBinding)

function LedBinding:__init(b, s, x)
  ComputedBinding.__init(self, b, s, x)
end

function LedBinding:init()
  self.cursor = self.schema_manager:copy_cursor()
  self.to_led = self.binding.to_led or function(c, s, x) return x and 2 or 0 end
  if type(self.binding.value) == 'string' then
    self.val = function() return self:resolve(self.binding.value) end
  elseif type(self.binding.value) == 'function' then
    self.val = self.binding.value
  else
    self.val = function() return self.binding.value end
  end
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
  self.led = self:eval(self:resolve(self.binding.led))
  local obs_source = self:resolve(self.binding.obs)
  self.observable = self:eval(obs_source)
  mm:update_binding(obs_source .. self.suffix, ObservableMapping(obs_source, self.observable, self.callback, true))
end




class "ScreenBinding" (ComputedBinding)

function ScreenBinding:__init(b, s, x)
  ComputedBinding.__init(self, b, s, x)
end

function ScreenBinding:init()
  self.callback = function()
    local config = self:resolve(self.binding.scribble)
    if config ~= nil then self.xtouch:push_scribble_strip(config.channel, config, config.ttl) end
  end
end

function ScreenBinding:update(mm)
  self.cursor = self.schema_manager:copy_cursor()
  if self.binding.obs then
    local trigger_source = self:resolve(self.binding.obs)
    local trigger = self:eval(trigger_source)
    mm:update_binding(trigger_source .. self.suffix, ObservableMapping(trigger_source, trigger, self.callback, self.binding.immediate))
  elseif self.binding.xtouch then
    local source = self:resolve(self.binding.obs)
    local widget, event = self:eval(source)
    mm:update_binding(trigger_source .. self.suffix, XTouchMapping(source, widget, event, self.callback, self.binding.immediate))
  end
  -- mm:update_binding('scribble strip #' .. self.cursor.channel, ScreenMapping())
end




class "SimpleBinding" (ComputedBinding)

function SimpleBinding:__init(b, s, x)
  ComputedBinding.__init(self, b, s, x)
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
    mm:update_binding(source .. self.suffix, XTouchMapping(source, widget, event, self.callback))
  else
    mm:update_binding(source .. self.suffix, ObservableMapping(source, self:eval(source), self.callback))
  end
end




class "VuBinding" (ComputedBinding)

function VuBinding:__init(b, s, x)
  ComputedBinding.__init(self, b, s, x)
end

function VuBinding:init()
end

function VuBinding:update(mm)
  self.cursor = self.schema_manager:copy_cursor()
  local vu = self:eval(self:resolve(self.binding.vu))
  if vu ~= nil then
    local track = self:eval(self:resolve(self.binding.track))
    if track ~= nil then
      local post = self:eval(self:resolve(self.binding.post))
      if post ~= nil then
        local right_of = self:eval(self:resolve(self.binding.right_of))
        -- print('VuBinding', vu, right_of, track, post)
        mm:update_binding('VU#' .. vu, VuMapping(vu, track, right_of, post))
      end
    end
  end
end
-- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == -- == --
