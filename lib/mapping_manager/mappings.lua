class "Mapping"

function Mapping:__init(source, callback)
  self.source = source
  self.orig_callback = callback
  self.callback = function(a, b, c, d)
    xpcall(function() callback(a, b, c, d) end, function(err)
      print("[xtouch] Error in callback for " .. source .. ": " .. err)
      print(err)
      print('')
      print(debug.traceback())
    end)
  end
  if callback == nil then
    print("[xtouch] WARNING NULL CALLBACK", source)
  end
end

function Mapping:is_equal_to(other)
  if type(self) ~= type(other) then return false end
  return self.source == other.source and self.orig_callback == other.orig_callback
end


function Mapping:on(mm) end
function Mapping:off(mm) end
function Mapping:refresh(mm) end


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
  print(self.source, self.widget, self.event, self.callback)
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


function XTouchMapping:refresh(mm)
  if self.immediate then
    self.callback()
  end
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
  -- if obs == nil then
  --   print(source, "NO OBSERVABLE")
  -- end
end

function ObservableMapping:is_equal_to(other)
  return Mapping.is_equal_to(self, other) and rawequal(self.observable, other.observable)
end

function ObservableMapping:on(mm)
  if not self.observable  or not self.callback then return end
  if self.observable == nil then print('[xtouch]', self.source, "have no observable") end
  if self.callback == nil then print('[xtouch]', self.source, "have no callback") end
  if self.observable ~= nil and not self.observable:has_notifier(self.callback) then
    self.observable:add_notifier(self.callback)
  end
  if self.immediate then
    self.callback()
  end
end

function ObservableMapping:off(mm)
  if not self.observable  or not self.callback then return end
  if self.observable:has_notifier(self.callback) then
    self.observable:remove_notifier(self.callback)
  end
end

function ObservableMapping:refresh(mm)
  if self.immediate then
    self.callback()
  end
end



class "VuMapping"

function VuMapping:__init(vu, track, right_of, post)
  self.vu = vu
  self.track = track
  self.right_of = right_of
  self.post = post
end

function VuMapping:on(mm)
  mm.xtouch:tap(self.track, self.right_of, self.vu, self.post)
end

function VuMapping:off(mm)
  mm.xtouch:untap(self.vu)
end

function VuMapping:is_equal_to(other)
  return self.vu == other.vu and rawequal(self.track, other.track) and rawequal(self.right_of, other.right_of) and self.post == other.post
end


function VuMapping:refresh(mm) end


class "ScreenMapping"

function ScreenMapping:__init(widget, config)
  print("ScreenMapping", widget, config)
  self.channel = widget._channel_ or widget
  self.config = config
end

function ScreenMapping:is_equal_to(other)
  return (self.channel == other.channel
          and self.config.line1 == other.config.line1
          and self.config.line2 == other.config.line2
          and self.config.inverse == other.config.inverse
          and (self.color == nil and other.color == nil
            or self.color ~= nil and other.color ~= nil and
            self.color[1] == other.color[1] and
            self.color[2] == other.color[2] and
            self.color[3] == other.color[3]
          )
  )
end


function ScreenMapping:on(mm)
  mm.xtouch:push_scribble_strip(self.channel, self.config, self.config and self.config.ttl)
end

function ScreenMapping:off(mm)
  mm.xtouch:pop_scribble_strip(self.channel, self.config.id)
end

function VuMapping:refresh(mm) end
