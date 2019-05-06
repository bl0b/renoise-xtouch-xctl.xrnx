-- Gotta define the life cycle better.
-- A track has or hasn't the hack installed and is or is not mapped to an X-Touch track.
-- The VU hack should ALWAYS be the last device on a track.

_AUTO_RELOAD_DEBUG = function()
  print('Reloaded X-Touch tool.')
end

local vu_count = 0

local send_prefix = 'XT LED #'
local tap_prefix = 'XT Tap #'

function is_name_a(prefix, name)
  return name:sub(1, #prefix) == prefix
end


function spawn_gainer(track_number, name)
  -- print('spawn_gainer', track_number, name)
  -- spawn a gainer at the end of the device list, configure it, and return it.
  local t = renoise.song().tracks[track_number]
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
  sf.parameters[1].value = target_track - 1
  -- * Dest. Effect
  sf.parameters[2].value = target_device
  sf.parameters[3].value = 1
  -- * Dest. Min
  sf.parameters[4].value = 0
  -- * Dest. Max
  sf.parameters[5].value = .25
  -- * Dest. Offset
  sf.parameters[6].value = .5
  -- * Attack
  sf.parameters[7] = 0
  -- * Release
  sf.parameters[8] = .15
  -- * Sensitivity
  sf.parameters[9] = .5
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
    -- print('Track Vol?', track.devices[1].parameters[2].name)
    track.devices[1].parameters[2].value = 1
    track.devices[1].parameters[5].value = 0
    track.collapsed = true
    local sf = spawn_signal_follower(st, 2)
    local g = spawn_gainer(st, send_prefix .. channel .. '-g')
    configure_signal_follower(sf, send_prefix .. channel .. '-sf', st, 2)
  --end
  return st - m - 1
end


function master_index()
  local tracks = renoise.song().tracks
  for i = #tracks, 1, -1 do
    if tracks[i].type == 2 then
      -- print('on master', i)
      return i
    end
  end
  return -1
end


function XTouch:cleanup_LED_support()
  local song = renoise.song()
  local tracks = song.tracks
  for _ = #tracks, 1, -1 do
    local t = tracks[_]
    -- print('CLEANUP ON TRACK', t.name, is_name_a(send_prefix, t.name), t.type == renoise.Track.TRACK_TYPE_SEND, t.type, renoise.Track.TRACK_TYPE_SEND)
    if t.type == renoise.Track.TRACK_TYPE_SEND and is_name_a(send_prefix, t.name) then
      song:delete_track_at(_)
    else
      for i = #t.devices, 1, -1 do
        -- print('CLEANUP ON TRACK', t.name, 'DEVICE', t.devices[i].display_name)
        if is_name_a(tap_prefix, t.devices[i].display_name) then
          t:delete_device_at(i)
        end
      end
    end
  end
end


function XTouch:init_LED_support()
  print('init VU sends')
  self:cleanup_LED_support()
  self.vu_tracks = {}
  self.vu_backend = {}
  self.vu_hooks = {}
  self.vu_unbind = {}
  self.taps = self.taps or {}
  local mi = master_index()
  for i = 1, 8 do
    self.vu_tracks[i] = ensure_send_track(i, mi)
    -- print('send track #' .. i, self.vu_tracks[i])
    self.vu_backend[i] = renoise.song().tracks[mi + 1 + self.vu_tracks[i]].devices[3]
    -- print('vu_backend#' .. i, self.vu_backend[i])
    local param = self.vu_backend[i].parameters[1]
    local base_channel = (i - 1) * 16
    self.vu_hooks[i] = function()
      local value = 8 * param.value
      if value > 15 then value = 15 end
      self:send({0xd0, base_channel + value})
    end
    if not param.value_observable:has_notifier(self.vu_hooks[i]) then
      param.value_observable:add_notifier(self.vu_hooks[i])
    end
    if self.taps[i] then
      self:tap(self.taps[i].track, self.taps[i].at, i)
    end
  end
end



function XTouch:config_string_for_Send(channel, post_if_true)
  return [[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="11">
  <DeviceSlot type="SendDevice">
    <IsMaximized>false</IsMaximized>
    <SendAmount>
      <Value>1.0</Value>
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
  if self.vu_unbind[channel] then
    if self.vu_enabled.value then
      self.vu_unbind[channel]()
    end
    self.vu_unbind[channel] = nil
    self.taps[channel] = nil
  end
end

function XTouch:tap(track_index, at, channel, post_if_true)
  -- print('tap')
  if self.vu_unbind[channel] ~= nil then
    self.vu_unbind[channel]()
  end
  local track = renoise.song().tracks[track_index]
  local send = track:insert_device_at('Audio/Effects/Native/#Send', at or (#track.devices + 1))
  send.active_preset_data = self:config_string_for_Send(channel, post_if_true)
  send.display_name = tap_prefix .. channel
  self.vu_unbind[channel] = function()
    if self.vu_enabled.value then
      local track = renoise.song().tracks[track_index]
      -- print('DEBUG UNBIND', track, track.devices)
      for i, d in ipairs(track.devices) do
        if d.display_name == send.display_name then
          track:delete_device_at(i)
        end
      end
      --local d = track.devices:find(send)
      --if d > 0 then
        --track:delete_device_at(d)
      --end
    end
  end
  self.taps[channel] = {track=track_index, at=at}
end
