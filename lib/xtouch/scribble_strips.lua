function XTouch:init_scribble_strip_process()
  self.scribble_config_stacks = {{}, {}, {}, {}, {}, {}, {}, {}}
  self.scribble_displayed_at = {0, 0, 0, 0, 0, 0, 0, 0}
  self.scribble_index_by_id = {{}, {}, {}, {}, {}, {}, {}, {}}

  renoise.tool().app_idle_observable:add_notifier({self, self.update_scribble_strips})
end


function XTouch:push_scribble_strip(channel, config)
  if config.id == nil then
    error('screen config MUST have an id')
  end
  -- rprint(config)
  local cfg = table.copy(config)
  cfg.created_at = os.clock()
  cfg.displayed_at = 0
  if cfg.ttl == nil then
    -- print('no ttl')
    -- print(channel)
    -- rprint(cfg)
    self.scribble_index_by_id[channel] = {[cfg.id] = 1}
    self.scribble_config_stacks[channel] = {cfg}
  elseif self.scribble_index_by_id[channel][cfg.id] then
    local i = self.scribble_index_by_id[channel][cfg.id]
    -- print('already exists', i)
    local stack = self.scribble_config_stacks[channel]
    stack[i] = cfg
    stack[#stack].displayed_at = 0
  else
    -- print('new layer')
    local i = #self.scribble_config_stacks[channel] + 1
    self.scribble_config_stacks[channel][i] = cfg
    self.scribble_index_by_id[channel][cfg.id] = i
  end
  -- print("push_scribble_strip", config.channel, config.id, #self.scribble_config_stacks[config.channel])
end


function pop_scribble_strip(channel, id)
  if not self.scribble_index_by_id[channel][id] then return end
  local tab = {}
  local dic = {}
  local stack = self.scribble_config_stacks[channel]
  local j = 0
  for i = 1, #stack do
    if stack[i].id ~= id then
      j = j + 1
      tab[j] = stack[i]
      dic[tab[j].id] = j
      if j > 1 then tab[j - 1].displayed_at = 0 end
    end
  end
  self.scribble_config_stacks[channel] = tab
  self.scribble_index_by_id[channel] = dic
end


local next_frame_timestamp = 0

function update_screen_field(screen, config, field, index)
  local v = index and (config[field] and config[field][index] or nil) or config[field]
  local prop = index and screen:property(field)[index] or screen:property(field)
  if v and prop.value ~= v then
    -- print('update_screen_field', field, index, v)
    prop.value = v
    return true
  end
  return false
end


function update_screen(screen, config)
  local updated = update_screen_field(screen, config, 'line1')
  updated = update_screen_field(screen, config, 'line2') or updated
  updated = update_screen_field(screen, config, 'inverse') or updated
  updated = update_screen_field(screen, config, 'color', 1) or updated
  updated = update_screen_field(screen, config, 'color', 2) or updated
  updated = update_screen_field(screen, config, 'color', 3) or updated
  -- print("update_screen result", updated)
  return updated
end


function XTouch:update_scribble_strips()
  local timestamp = os.clock()

  if timestamp < next_frame_timestamp then
    return
  end
  next_frame_timestamp = timestamp + self.scribble_frame_duration
  -- print('[xtouch] scribble frame')

  for channel = 1, 8 do
    -- print('[xtouch] scribble #' .. channel)
    -- remove expired layers
    local tab = {}
    local dic = {}
    local stack = self.scribble_config_stacks[channel]
    local refresh = false
    local i = #stack
    local j = 0
    for i = 1, #stack do
      if stack[i].ttl and not stack[i].remove_after then
        stack[i].remove_after = timestamp + stack[i].ttl
      end
      if not (stack[i].remove_after and stack[i].remove_after < timestamp) then
        j = j + 1
        tab[j] = stack[i]
        dic[tab[j].id] = j
      else
        refresh = true
      end
    end
    self.scribble_config_stacks[channel] = tab
    self.scribble_index_by_id[channel] = dic
    -- if channel == 3 then rprint(tab) end

    local top_layer = tab[#tab]

    -- deploy if necessary
    if top_layer and (refresh or top_layer.displayed_at == 0) then
      -- rebuild current screen configuration
      local screen = self.channels[channel].screen
      local config
      if #tab == 0 then
        config = {line1 = '', line2 = '', inverse = false, color = {0, 0, 0}, id = 'off', displayed_at = 0}
      else
        config = {}
        for i = 1, #tab do
          for k, v in pairs(tab[i]) do
            config[k] = v
          end
        end
      end
      -- if channel == 3 then
      --   print('------')
      --   rprint(config)
      --   print('==================')
      -- end

      if update_screen(screen, config) then
        top_layer.displayed_at = timestamp
        self.screen_bang[channel]:bang()
        self:send_strip(channel)
      end
    end
  end
end


function XTouch:terminate_scribble_strip_process()
  local a = renoise.tool().app_idle_observable
  if a:has_notifier({self, self.update_scribble_strips}) then
    a:remove_notifier({self, self.update_scribble_strips})
  end
end
