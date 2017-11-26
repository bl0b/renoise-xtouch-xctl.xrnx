function XTouch:detach_VU(track_index)
  local vu = self.vu_hack[track_index]
  local t = renoise.song().tracks[track_index]
  --t.delete_device_at(vu.index)  -- delete SF
  --t.delete_device_at(vu.index)  -- delete gainer
  -- notifier is implicitly removed when deleting the gainer…
end



function XTouch:attach_VU_to_track(track_index, channel)
  local track = renoise.song().tracks[track_index]
  local sf_name = 'VU#'..channel.."_sf"
  local g_name = 'VU#'..channel.."_g"
  if self.vu_hack[track_index] == nil then
    self.vu_hack[track_index] = {}
  end
  local vu = self.vu_hack[track_index]
  --print("attaching VU #", channel, "to track #", track_index)
  if vu.attached == true then
    self:detach_VU(track_index)
  end
  local sf = nil
  local g = nil
  vu.sf_index = 0
  vu.g_index = 0
  for i = 1, #track.devices do
    if track.devices[i].display_name == sf_name then
      vu.sf_index = i
    elseif track.devices[i].display_name == g_name then
      vu.g_index = i
    end
  end
  if vu.sf_index == 0 then
    vu.sf_index = #track.devices + 1
    sf = track:insert_device_at('Audio/Effects/Native/*Signal Follower', vu.sf_index)
   else
    sf = track:device(vu.sf_index)
  end
  if vu.g_index == 0 then
    vu.g_index = #track.devices + 1
    g = track:insert_device_at('Audio/Effects/Native/Gainer', vu.g_index)
  else
    g = track:device(vu.g_index)
  end
  if vu.sf_index > vu.g_index then
    track:swap_devices_at(vu.sf_index, vu.g_index)
    vu.sf_index, vu.g_index = vu.g_index, vu.sf_index
  end
  --print("g_index", vu.g_index, g.display_name, "sf_index", vu.sf_index, sf.display_name)
  --print(sf.active_preset_data)
  sf.is_maximized = true
  sf.display_name = sf_name
  g.is_maximized = false
  g.display_name = g_name
  -- disable gainer (we just want to observe the gain parameter value)
  g.is_active = false
  -- set follower params
  -- * Attack
  sf.parameters[7] = 0
  -- * Release
  sf.parameters[8] = .3
  -- * Sensitivity
  sf.parameters[9] = .75
  -- * LP Filter
  -- * HP Filter
  -- * Dest. Min
  sf.parameters[4].value = 0
  -- * Dest. Max
  sf.parameters[5].value = .25
  -- * Dest. Offset
  sf.parameters[6].value = .5
  -- * Dest. Track
  sf.parameters[1].value = -1
  -- * Dest. Effect
  --oprint(sf.parameters[2])
  --print(sf.parameters[2])
  sf.parameters[2].value = vu.g_index - 1 
  sf.parameters[3].value = 1
  --print(sf.parameters[2])
  print(sf.parameters[2].value)
  -- * Dest. Parameter

  vu.channel = channel
  
  vu.observed = g.parameters[1]

  channel = (channel - 1) * 16
  vu.hook = function()
    local value = 8 * vu.observed.value
    if value > 15 then value = 15 end
    self:send({0xd0, channel + value})
  end
  
  if not vu.observed.value_observable:has_notifier(vu.hook) then
    vu.observed.value_observable:add_notifier(vu.hook)
  end
end

