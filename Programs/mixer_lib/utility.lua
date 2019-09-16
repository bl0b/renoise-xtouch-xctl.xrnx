function led_center_strip(cursor, state, v)
  -- print('led_center_strip', type(v), v)
  -- >>> for i = 12, 0, -1 do print('elseif v >', 1.0 * i / 13, 'then return ') end
  if     v >  0.9230 then return 0x003f
  elseif v >  0.8461 then return 0x001f
  elseif v >  0.7692 then return 0x000f
  elseif v >  0.6923 then return 0x0007
  elseif v >  0.6153 then return 0x0003
  elseif v >  0.5384 then return 0x0001
  elseif v >  0.4615 then return 0x1000
  elseif v >  0.3846 then return 0x1800
  elseif v >  0.3076 then return 0x1c00
  elseif v >  0.2307 then return 0x1e00
  elseif v >  0.1538 then return 0x1f00
  elseif v >  0.0769 then return 0x1f80
  elseif v >= 0      then return 0x1fc0
  end
  return 0
end


function led_full_strip_lr(cursor, state, v)
  -- print('led_full_strip_lr')
  -- >>> for i = 12, 0, -1 do print('elseif v >', 1.0 * i / 13, 'then return ') end
  if     v >  0.9230 then return 0x1fff
  elseif v >  0.8461 then return 0x1fdf
  elseif v >  0.7692 then return 0x1fcf
  elseif v >  0.6923 then return 0x1fc7
  elseif v >  0.6153 then return 0x1fc3
  elseif v >  0.5384 then return 0x1fc1
  elseif v >  0.4615 then return 0x1fc0
  elseif v >  0.3846 then return 0x0fc0
  elseif v >  0.3076 then return 0x07c0
  elseif v >  0.2307 then return 0x03c0
  elseif v >  0.1538 then return 0x01c0
  elseif v >  0.0769 then return 0x00c0
  elseif v >= 0      then return 0x0040
  end
  return 0
end


function led_full_strip_rl(cursor, state, v)
  -- >>> for i = 12, 0, -1 do print('elseif v >', 1.0 * i / 13, 'then return ') end
  if     v >  0.9230 then return 0x0020
  elseif v >  0.8461 then return 0x0030
  elseif v >  0.7692 then return 0x0038
  elseif v >  0.6923 then return 0x003c
  elseif v >  0.6153 then return 0x003e
  elseif v >  0.5384 then return 0x003f
  elseif v >  0.4615 then return 0x103f
  elseif v >  0.3846 then return 0x183f
  elseif v >  0.3076 then return 0x1c3f
  elseif v >  0.2307 then return 0x1e3f
  elseif v >  0.1538 then return 0x1f3f
  elseif v >  0.0769 then return 0x1fbf
  elseif v >= 0      then return 0x1fff
  end
  return 0
end


-- https://stackoverflow.com/a/15278426
function TableConcat(t1, t2)
  for i = 1, #t2 do
      t1[#t1 + 1] = t2[i]
  end
  return t1
end


function plug_schema(target, plugin)
  if plugin.state then
    target.state:add_properties(plugin.state)
  end
  if plugin.assign then
    target.assign = TableConcat(target.assign, plugin.assign)
  end
  if plugin.frame and target.frame then
    target.frame.assign = TableConcat(target.frame.assign, plugin.frame.assign)
  end
end





function to_xtouch(source, event)
  local t = type(source)
  --oprint(source)
  return event ~= nil and (t == 'DocumentNode' and source.path ~= nil or t == 'string')
end


function master_track()
  local tracks = renoise.song().tracks
  for i =  #tracks, 1, -1 do
    local t = renoise.song():track(i)
    if t.type == renoise.Track.TRACK_TYPE_MASTER then return t end
  end
end


function master_track_index()
  local tracks = renoise.song().tracks
  for i =  #tracks, 1, -1 do
    local t = renoise.song():track(i)
    if t.type == renoise.Track.TRACK_TYPE_MASTER then return i end
  end
end


function strip_vowels(str)
  if str:len() <= 7 then return str end
  local initial = str:sub(1, 1)
  local rest = str:sub(2)
  return string.sub(initial .. string.gsub(rest, '[aeiouyAEIOUY ]', ''), 1, 7)
end


function format_value(value_string)
  if #value_string > 7 then
    -- print('format_value', value_string, #value_string, value_string:sub(#value_string - 2))
    local c = value_string:sub(#value_string)
    if c >= 'a' and c <= 'z' or c >= 'A' and c <= 'Z' then
      local d = value_string:find(' ')
      local unit_len = #value_string - d
      value_string = value_string:sub(1, 7 - unit_len) .. value_string:sub(-unit_len)
    else
      value_string = strip_vowels(value_string)
    end
  end
  return value_string
end


function pre_post_p(cursor, state)
  if renoise.app().window.mixer_view_post_fx then
    -- return renoise.song().tracks[cursor.track].postfx_volume
    return renoise.song().tracks[cursor.track].devices[1].parameters[5]
  else
    -- return renoise.song().tracks[cursor.track].prefx_volume
    return renoise.song().tracks[cursor.track].devices[1].parameters[2]
  end
end


function pre_post_obs(cursor, state)
  if renoise.app().window.mixer_view_post_fx then
    return 'cursor.track.postfx_volume'
  else
    return 'cursor.track.prefx_volume'
  end
end


function pre_post_value(cursor, state)
  if renoise.app().window.mixer_view_post_fx then
    return cursor.track.postfx_volume
  else
    return cursor.track.prefx_volume
  end
end



function transport_ofs(seq_ofs, beat_ofs)
  local len = renoise.song().transport.song_length
  local pos
  if renoise.song().transport.playing then
    pos = renoise.song().transport.playback_pos
  else
    pos = renoise.song().transport.edit_pos
  end
  pos.sequence = pos.sequence + seq_ofs
  if pos.sequence < 1 then pos.sequence = 1 end
  if pos.sequence > len.sequence then pos.sequence = len.sequence end
  if renoise.song().transport.playing then
    renoise.song().transport.playback_pos = pos
  else
    renoise.song().transport.edit_pos = pos
  end
end


function find_device_parameter(track, device, param)
  local T = renoise.song().tracks
  local t = track <= #T and T[track] or nil
  if t == nil then return end
  local d = device <= #t.devices and t.devices[device] or nil
  if d == nil then return end
  return param <= #d.parameters and d.parameters[param] or nil
end


function all_usable_tracks()
  local ret = table.create()
  local M, S = renoise.Track.TRACK_TYPE_MASTER, renoise.Track.TRACK_TYPE_SEND
  for i = 1, #renoise.song().tracks do
    local trk = renoise.song():track(i)
    if trk.type ~= M and (trk.type ~= S or string.sub(trk.name, 1, 8) ~= 'XT LED #') then
      ret:insert(trk)
    end
  end
  return ret
end


function all_usable_track_indices()
  local ret = table.create()
  local M, S = renoise.Track.TRACK_TYPE_MASTER, renoise.Track.TRACK_TYPE_SEND
  for i = 1, #renoise.song().tracks do
    local trk = renoise.song():track(i)
    if trk.type ~= M and (trk.type ~= S or string.sub(trk.name, 1, 8) ~= 'XT LED #') then
      ret:insert(i)
    end
  end
  return ret
end




function to_fader_device_param(xtouch, device, param, value)
  -- print(xtouch, device, param, value)
  local p = device and device:parameter(param) or param
  if p == nil then return end
  if p.value_string:sub(-2) == 'dB' then
    if value == p.value_min then return 0 end
    local param_db_max = math.lin2db(p.value_max)
    local db_min = p.value_min == 0 and (param_db_max - xtouch.fader_db_range) or math.lin2db(p.value_min)
    if value == nil then return 0 end
    local value_db = math.lin2db(value)
    return math.db2fader(db_min, param_db_max, value_db)
  else
    local min = p.value_min
    local max = p.value_max
    local ret = (value - min) / (max - min)
    if ret < min then ret = min end
    if ret > max then ret = max end
    return ret
  end
end


local fader_epsilon = 0.001

function from_fader_device_param(xtouch, device, param, value)
  local p = device and device:parameter(param) or param
  if p == nil then return end
  if p.value_string:sub(-2) == 'dB' then
    if value < fader_epsilon then return p.value_min end
    local param_db_max = math.lin2db(p.value_max)
    local db_min = p.value_min == 0 and (param_db_max - xtouch.fader_db_range) or math.lin2db(p.value_min)
    local fader_db = math.fader2db(db_min, param_db_max, value)
    return math.db2lin(fader_db)
  else
    local min = p.value_min
    local max = p.value_max
    local ret = min + value * (max - min)
    if ret < min then ret = min end
    if ret > max then ret = max end
    return ret
  end
end

