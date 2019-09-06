class "Mapping" (renoise.Document.DocumentNode)

function Mapping:__init(source, callback)
  self.source = source
  self.callback = callback
  if callback == nil then
    print("WARNING NULL CALLBACK", source)
  end
end

function Mapping:is_equal_to(other)
  if type(self) ~= type(other) then return false end
  return self.source == other.source and self.callback == other.callback
end


function Mapping:on(mm) end
function Mapping:off(mm) end




class "XTouchMapping" (Mapping)

function XTouchMapping:__init(source, widget, event, callback, immediate)
  Mapping.__init(self, source, callback)
  self.widget = widget
  self.event = event
  self.immediate = immediate or false
end

function XTouchMapping:is_equal_to(other)
  return Mapping.is_equal_to(self, other) and rawequal(self.widget, other.widget) and self.event == other.event
end

function XTouchMapping:on(mm)
  -- print(self.source, self.widget, self.event, self.callback)
  if self.widget == nil then print(self.source, "have no widget") end
  if self.event == nil then print(self.source, "have no event") end
  if self.callback == nil then print(self.source, "have no callback") end
  if self.widget == nil or self.event == nil or self.callback == nil then return end
  mm.xtouch:on(self.widget, self.event, self.callback)
  if self.immediate then
    self.callback()
  end
end

function XTouchMapping:off(mm)
  if self.widget == nil or self.event == nil or self.callback == nil then return end
  mm.xtouch:off(self.widget, self.event)
end




class "ObservableMapping" (Mapping)

function ObservableMapping:__init(source, obs, callback, immediate)
  Mapping.__init(self, source, callback)
  self.immediate = immediate or false
  if type(obs) == 'DeviceParameter' then
    self.observable = obs.value_observable
  else
    self.observable = obs
  end
  if obs == nil then
    print(source, "NO OBSERVABLE")
  end
end

function ObservableMapping:is_equal_to(other)
  return Mapping.is_equal_to(self, other) and rawequal(self.observable, other.observable)
end

function ObservableMapping:on(mm)
  if self.observable == nil then print(self.source, "have no observable") end
  if self.callback == nil then print(self.source, "have no callback") end
  if self.observable == nil or self.callback == nil then return end
  if self.source:sub(1, 5) == 'state' then print(self.source, type(self.observable), self.observable) end
  if not self.observable:has_notifier(self.callback) then
    self.observable:add_notifier(self.callback)
  end
  if self.immediate then
    self.callback()
  end
end

function ObservableMapping:off(mm)
  if self.observable == nil or self.callback == nil then return end
  if self.observable:has_notifier(self.callback) then
    self.observable:remove_notifier(self.callback)
  end
end




class "VuMapping" (renoise.Document.DocumentNode)

function VuMapping:__init(vu, track, at, post)
  self.vu = vu
  self.track = track
  self.at = at
  self.post = post
end

function VuMapping:on(mm)
  mm.xtouch:tap(self.track, self.at, self.vu, self.post)
end

function VuMapping:off(mm)
  mm.xtouch:untap(self.vu)
end

function VuMapping:is_equal_to(other)
  return self.vu == other.vu and self.track == other.track and self.at == other.at and self.post == other.post
end

