-- 20171110 bl0b
-- based on great documentation by FK http://www.budgetfeatures.com/XctlDOC/Xctl%20Protocol%20for%20X-Touch%20V1.0.pdf
require 'lib/lib'

-- Reload the script whenever this file is saved. 
-- Additionally, execute the attached function.
_AUTO_RELOAD_DEBUG = function()
  print('Reloaded X-Touch tool.')
end

local tool = renoise.tool()
local state_filename = os.currentdir() .. '/`state'

class "XTouch" (renoise.Document.DocumentNode)


function XTouch:save_state()
  -- self:save_as(state_filename)
end


-- Release resources
function XTouch:close(save)
  print('[xtouch] close')
  if self.input ~= nil and self.input.is_open then
    self.input:close()
  end
  if self.output ~= nil and self.output.is_open then
    self.output:close()
  end
  self.closed = true
  pcall(function() renoise.tool():remove_timer({self, self.ping}) end)
  if save then self:save_as(state_filename) end
end



function XTouch:load_state()
  -- if io.exists(state_filename) then
    -- self:load_from(state_filename)
    -- for i = 1, 8 do self:send_strip(i) end
  -- end
  -- self:cleanup_LED_support()
  -- self:init_program_manager()

  -- self:select_program(self._program_number.value)
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
function XTouch:post_init_button(ret, typ)
  local long
  typ = typ or 'button'
  long = function()
    --print('running long_press…')
    if tool:has_timer(long) then
      tool:remove_timer(long)
      self:trigger(typ, 'long_press', ret)
    end
  end

  ret.state:add_notifier(function()
    --print("button state", ret.state.value, ret.path)
    if ret.state.value then
      self:trigger(typ, 'press', ret)
      --print("long_press_ms", self.long_press_ms)
      tool:add_timer(long, self.long_press_ms * 1.0)  -- weird complaint about how it's not a double. so just ensure it is.
    else
      self:trigger(typ, 'release', ret)
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
  -- ret.state:add_notifier(function()
    -- self:trigger('encoder', ret.state.value and 'press' or 'release', ret)
  -- end)
  self:post_init_button(ret, 'encoder')
  ret.delta:add_notifier(function()
    --print(ret.path)
    self:trigger('encoder', 'delta', ret)
  end)
  self.hooks[ret.path.value] = {press = {}, release = {}, long_press = {}, delta = {}, any = {}}
end



function XTouch:get_hooks(event, path)
  return self.hooks[path][event]
end


function XTouch:run_hooks(event, path, real_event, widget)
  -- print("callbacks for", event, path, widget.path, self:get_hooks(event, path), self:get_hooks(event, path) and #self:get_hooks(event, path))
  for _, callback in pairs(self:get_hooks(event, path)) do
    --print(type(callback))
    if callback(real_event, widget) then
      return true
    end
  end
  return false
end



function XTouch:trigger(category, event, widget)
  -- xpcall(
    -- function()
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
  -- print('trigger '..category..' '..event)
  --   end,
  --   function(err)
  --     print("An error occured while triggering ", widget.path.value, " category =", category, " event =", event)
  --     print(err)
  --     print(debug.traceback())
  --   end
  -- )
end


function XTouch:on(where, when, how)
  local path = where.path ~= nil and where.path.value or where
  -- print("ON '" .. path .. "' type=" .. type(path), "when=", when)
  if self.hooks[path] == nil then
    print(path, 'not found')
    --local keys = ''
    --for k, _ in pairs(self.hooks) do
    --  keys = keys .. ',' .. k.value
    --end
    --print("have keys", keys)
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
  pcall(function() table.remove(self.hooks[where.path.value or where][when]) end)
end


require 'lib/xtouch/program_manager'
require 'lib/xtouch/scribble_strips'

function XTouch:config(options)
  self.in_name = options.input_device.value
  self.out_name = options.output_device.value
  self.long_press_ms = options.long_press_ms.value
  self.ping_period = options.ping_period.value
  self.vu_ceiling = options.vu_ceiling.value
  self.vu_floor = options.vu_floor.value
  self.vu_range = options.vu_range.value
  self.scribble_fps = options.scribble_fps or 60
  self.scribble_frame_duration = 1.0 / self.scribble_fps
  self.fader_db_range = options.fader_db_range or 80
  self.vu_fps = options.vu_fps or 50
  self.vu_frame_duration = 1. / self.vu_fps
  if self.programs then
    for i = 1, #self.programs do
      local p = self.programs[i]
      print('on program', p.name)
      for name, meta in pairs(p.config_meta) do
        local a, b = p.config[name], options.program_config[p.name][name].value
        if a.value ~= b then
          print('updating', p.name, name, a.value, b)
          a.value = b
        else
          print('not updating', p.name, name, a.value)
        end
      end
    end
  end
end

-- Controller class Ctor
function XTouch:__init(options)

  local button_auto_led = {press = 2, release = 0, long_press = 1}
  --print("CTOR XTouch")

  self.programs = {}
  self:config(options)

  self:init_scribble_strip_process()

  self.force_reset = renoise.Document.ObservableBang()

  self.model = renoise.Document.ObservableString('none')

  self.hooks = {
    any_button = {
      any = {
        -- function(event, widget)
        --   --print("ANY BUTTON!", event, widget.path)
        --   widget.led.value = button_auto_led[event]
        --   return false
        -- end
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
      long_press = {},
      delta = {}
    }
  }

  self.post_init_widgets = {}
  
  renoise.Document.DocumentNode.__init(self)
  
  self.fader_timestamp = {0, 0, 0, 0, 0, 0, 0, 0, 0}
  
  self:init_annoyingly_big_data()

  -- self:load_state()

  self.transport.jog_wheel.delta:add_notifier(function()
    if self.transport.jog_wheel.delta.value ~= 0 then
      self:trigger('jog_wheel', 'delta', self.transport.jog_wheel)
    end
  end)
  self.hooks['transport.jog_wheel'] = {delta = {}}
  
  local out = function(msg) self:send(msg) end

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

  -- self.vu_hack = {}
--  local tracks = renoise.song().tracks
--  for i = 1, math.min(#tracks, 8) do
--    self:attach_VU_to_track(i, i)
--  end
  -- rprint(self.hooks)

  self:init_vu_state()

  self:cleanup_LED_support()

  self:open()

  self.vu_enabled.value = false

  self.vu_enabled:add_notifier(function()
    if self.vu_enabled.value then
      self:init_LED_support()
    else
      self:cleanup_LED_support()
    end
  end)

  self:init_program_manager(options)
  self:__select_program()
end


--function XTouch:__finalize()
--  if not self.closed then
--    self:close()
--  end
--end


function XTouch:send_lcd_string(start_digit, str)
  --print("send_lcd_digits")
  local stop = math.min(13 - start_digit, string.len(str))
  for i = 1, stop do
    local c = self.lcd_ascii[string.sub(str, i, i)]
    if c ~= nil then
      --print(start_digit, self.lcd_digits[start_digit])
      self.lcd_digits[start_digit].value = c
      start_digit = start_digit + 1
    end
  end
  while start_digit <= 12 do
    self.lcd_digits[start_digit].value = 0
    start_digit = start_digit + 1
  end
end


require 'lib/xtouch/midi'

require 'lib/xtouch/vu_hack'

require 'lib/xtouch/init_long_data'
