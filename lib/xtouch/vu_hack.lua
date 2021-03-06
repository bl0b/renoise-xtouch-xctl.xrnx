-- Gotta define the life cycle better.
-- A track has or hasn't the hack installed and is or is not mapped to an X-Touch track.
-- The VU hack should ALWAYS be the last device on a track.

_AUTO_RELOAD_DEBUG = function()
  print('Reloaded X-Touch tool.')
end

local vu_count = 0

local send_prefix = 'XT VU #'
local tap_prefix = 'XT Tap #'

function is_name_a(prefix, name)
  return name:sub(1, #prefix) == prefix
end

function insert_device_to_the_right_of(device_to_insert, track, device)
  local target_index = (function() for i = 1, #track.devices do if rawequal(track:device(i), device) then return i end end return #track.devices end)()
  -- print('[xtouch] insert_device_to_the_right_of', device_to_insert, track.name, device and device.name or nil, target_index)
  return track:insert_device_at(device_to_insert, 1 + target_index)
end



function spawn_gainer(track_number, name)
  -- print('spawn_gainer', track_number, name)
  -- spawn a gainer at the end of the device list, configure it, and return it.
  local t = renoise.song():track(track_number)
  local g = t:insert_device_at('Audio/Effects/Native/Gainer', #t.devices + 1)
  g.is_maximized = false
  g.display_name = name
  -- disable gainer (we just want to observe the gain parameter value)
  g.is_active = false
  return {index=#t.devices, device=g}
end


function spawn_signal_follower(track_number, device_number)
  -- spawn a signal follower in the device list of the given track, configure it, and return it.
  -- spawn a gainer at the end of the device list, configure it, and return it.
  local t = renoise.song():track(track_number)
  local sf = t:insert_device_at('Audio/Effects/Native/*Signal Follower', device_number)
  return sf
end

function configure_signal_follower(sf, name, target_track, target_device)
  sf.is_maximized = true
  sf.display_name = name
  -- set follower params
  -- * Dest. Track
  sf:parameter(1).value = target_track - 1
  -- * Dest. Effect
  sf:parameter(2).value = target_device
  sf:parameter(3).value = 1
  -- * Dest. Min
  sf:parameter(4).value = 0
  -- * Dest. Max
  sf:parameter(5).value = .25
  -- * Dest. Offset
  sf:parameter(6).value = .5
  -- * Attack
  sf:parameter(7).value = 0.001
  -- * Release
  sf:parameter(8).value = .3
  -- * Sensitivity
  sf:parameter(9).value = .637
  -- * LP Filter
  -- * HP Filter
end


function ensure_send_track(channel, m)
  local tracks = renoise.song().tracks
  local st = #tracks + 1 -- -1
  local codename = send_prefix .. channel
  --for s = #tracks, m, -1 do
  --  if tracks[s].name == codename then
  --    st = s
  --  end
  --end
  --if st == -1 then
    st = #tracks + 1
    local track = renoise.song():insert_track_at(st)
    track.name = codename
    track.color = {0, 0, 0}
    -- print('Track Vol?', track:device(1):parameter(2).name)
    track:device(1):parameter(2).value = .5
    track:device(1):parameter(5).value = 0
    track.collapsed = true
    local sf = spawn_signal_follower(st, 2)
    local g = spawn_gainer(st, send_prefix .. channel .. '-g')
    configure_signal_follower(sf, send_prefix .. channel .. '-sf', st, 2)
  --end
  return st - m - 1
end


function master_index()
  for i = #renoise.song().tracks, 1, -1 do
    if renoise.song():track(i).type == 2 then
      -- print('on master', i)
      return i
    end
  end
  return -1
end


function XTouch:cleanup_LED_support()
  local song = renoise.song()
  local tracks = song.tracks
  local selected_track_index = renoise.song().selected_track_index
  for _ = #tracks, 1, -1 do
    local t = song:track(_)
    -- print('CLEANUP ON TRACK', t.name, is_name_a(send_prefix, t.name), t.type == renoise.Track.TRACK_TYPE_SEND, t.type, renoise.Track.TRACK_TYPE_SEND)
    if t.type == renoise.Track.TRACK_TYPE_SEND and is_name_a(send_prefix, t.name) then
      song:delete_track_at(_)
    else
      for i = #t.devices, 1, -1 do
        -- print('CLEANUP ON TRACK', t.name, 'DEVICE', t:device(i).display_name)
        if is_name_a(tap_prefix, t:device(i).display_name) then
          t:delete_device_at(i)
        end
      end
    end
  end
  renoise.song().selected_track_index = selected_track_index
  for i = 1, 8 do self.vu_unbind[i] = nil end
end


function XTouch:set_vu_range(ceiling, range)
  -- print('[xtouch] set VU range', ceiling, range)
  self.vu_ceiling = ceiling
  self.vu_floor = ceiling - range
  self.vu_range = range
end


function XTouch:init_vu_state()
  if self.vu_unbind then
    for i, u in ipairs(self.vu_unbind) do
      if u then u() end
    end
  end
  self.vu_tracks = {}
  self.vu_backend = {}
  self.vu_hooks = {}
  self.vu_unbind = {}
  self.taps = {{}, {}, {}, {}, {}, {}, {}, {}}
end


function XTouch:init_LED_support()
  -- print('[xtouch] init VU sends')
  self:cleanup_LED_support()
  -- self:init_vu_state()
  local mi = master_index()
  for i = 1, 8 do
    self.vu_tracks[i] = ensure_send_track(i, mi)
    -- print('send track #' .. i, self.vu_tracks[i])
    self.vu_backend[i] = renoise.song():track(mi + 1 + self.vu_tracks[i]):device(3)
    -- print('vu_backend#' .. i, self.vu_backend[i])
    local param = self.vu_backend[i]:parameter(1)
    local base_channel = (i - 1) * 16
    
    local last_frame_timestamp = 0

    self.vu_hooks[i] = function()
      local timestamp = os.clock()
      local dt = timestamp - last_frame_timestamp
      if dt < self.vu_frame_duration then return end
      last_frame_timestamp = timestamp
      local level = math.lin2db(param.value)
      local value
      -- if level >= self.vu_ceiling then
      --   value = 8
      -- else
      --   value = 7 * math.db2fader(self.vu_ceiling - self.vu_range, self.vu_ceiling, level)
      -- end
      if level < (self.vu_ceiling - self.vu_range) then value = 0
      elseif level >= self.vu_ceiling then value = 15
      else value = (level - self.vu_ceiling + self.vu_range) / self.vu_range * 8
      end
      -- print(string.format('led #%d ceiling=%d range=%d param=%3.3f level=%.3f value=%2.2f', i, self.vu_ceiling, self.vu_range, param.value, level, value))
      self:send({0xd0, base_channel + value})
    end
    
    if not param.value_observable:has_notifier(self.vu_hooks[i]) then
      param.value_observable:add_notifier(self.vu_hooks[i])
    end
    
    -- print(i, self.taps[i])
    -- rprint(self.taps[i])
    if self.taps[i] and not self.vu_unbind[i] then
      local t = self.taps[i]
      if t.track then
        self:tap(t.track, t.right_of, t.channel, t.post)
      end
    end
  end
end



function XTouch:config_string_for_Send(channel, post_if_true)
  -- print('config_string_for_Send', channel, post_if_true)
  -- rprint(self.vu_tracks)
  return [[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="11">
  <DeviceSlot type="SendDevice">
    <IsMaximized>false</IsMaximized>
    <SendAmount>
      <Value>.5</Value>
    </SendAmount>
    <SendPan>
      <Value>0.5</Value>
    </SendPan>
    <DestSendTrack>
      <Value>]] .. self.vu_tracks[channel] .. [[</Value>
    </DestSendTrack>
    <MuteSource>false</MuteSource>
    <SmoothParameterChanges>true</SmoothParameterChanges>
    <ApplyPostVolume>]] .. (post_if_true and 'true' or 'false') .. [[</ApplyPostVolume>
  </DeviceSlot>
</FilterDevicePreset>]]
end



function XTouch:untap(channel)
  if self.vu_enabled.value and self.vu_unbind[channel] then
    self.vu_unbind[channel]()
    self.vu_unbind[channel] = nil
  end
  self.taps[channel] = nil
end



function XTouch:tap(track, right_of, channel, post_if_true)
  -- print('[xtouch] tap', track, right_of, channel, post_if_true)
  if type(right_of) ~= 'AudioDevice' then right_of = nil end
  self.taps[channel] = {track=track, right_of=right_of, channel=channel, post=post_if_true}
  if not self.vu_enabled.value then
    return
  end
  if self.vu_unbind[channel] then
    self.vu_unbind[channel]()
    self.vu_unbind[channel] = nil
  end
  -- local track = renoise.song():track(track_index)
  if track == nil then
    print('[xtouch] While tapping', track_index, right_of, channel, post_if_true, ": no track.")
    return
  end
  local send = insert_device_to_the_right_of('Audio/Effects/Native/#Send', track, right_of)
  local active_preset_data = self:config_string_for_Send(channel, post_if_true)
  send.active_preset_data = active_preset_data
  for i, p in ipairs(send.parameters) do p.show_in_mixer = false end
  local display_name = tap_prefix .. channel
  send.display_name = display_name
  send.display_name_observable:add_notifier(function() if send.display_name ~= display_name then send.display_name = display_name end end)
  send.active_preset_observable:add_notifier(function() if send.active_preset_data ~= active_preset_data then send.active_preset_data = active_preset_data end end)
  self.vu_unbind[channel] = function()
    -- print('[xtouch] vu_unbind', channel)
    if self.vu_enabled.value then
      for i = 2, #track.devices do
        local d = track:device(i)
        -- print(i, #track.devices, d.display_name)
        if d ~= nil and d.display_name == send.display_name then
          track:delete_device_at(i)
          return
        end
      end
    end
  end
end
