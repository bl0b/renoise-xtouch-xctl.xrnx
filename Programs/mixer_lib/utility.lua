function led_center_strip(cursor, state, v)
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
    if tracks[i].type == renoise.Track.TRACK_TYPE_MASTER then return i end
  end
end


function strip_vowels(str)
  if str:len() <= 7 then return str end
  local initial = str:sub(1, 1)
  local rest = str:sub(2)
  return string.sub(initial .. string.gsub(rest, '[aeiouyAEIOUY ]', ''), 1, 7)
end


function render_track_name(cursor, state, screen, t)
  -- print('render_track_name', t, t.name)
  screen.line1.value = ''
  screen.line2.value = strip_vowels(t.name)
  screen.color[1].value = t.color[1]
  screen.color[2].value = t.color[2]
  screen.color[3].value = t.color[3]
  screen.inverse.value = true
end


function render_track_and_parameter_name(cursor, state, screen, t)
  local d = t.devices[1]
  local p = d and d.parameters[state.current_param[1].value] or nil
  -- print('render_track_and_parameter_name', t, d, p)
  if screen == nil then return end
  oprint(screen)
  screen.line1.value = strip_vowels(t and t.name or '---')
  screen.line2.value = strip_vowels(p and p.name or '---')
  screen.color[1].value = t.color[1]
  screen.color[2].value = t.color[2]
  screen.color[3].value = t.color[3]
  screen.inverse.value = true
end


function render_device_and_parameter_name(cursor, state, screen, t)
  local d = t.devices[cursor.device]
  local p = d and d.parameters[state.current_param[cursor.channel].value] or nil
  -- print('render_device_and_parameter_name', t, d, p)
  if screen == nil then return end
  screen.line1.value = strip_vowels(d and d.display_name or '---')
  screen.line2.value = strip_vowels(p and p.name or '---')
  screen.color[1].value = t.color[1]
  screen.color[2].value = t.color[2]
  screen.color[3].value = t.color[3]
  screen.inverse.value = true
end


function render_parameter_name(cursor, state, screen, t)
  local d = t.devices[1]
  local p = d and d.parameters[state.current_param[8].value] or nil
  -- print('render_parameter_name', t, d, p)
  if screen == nil then return end
  screen.line1.value = ''
  screen.line2.value = strip_vowels(p and p.name or '---')
  screen.color[1].value = t.color[1]
  screen.color[2].value = t.color[2]
  screen.color[3].value = t.color[3]
  screen.inverse.value = true
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
    return 'renoise.song().tracks[' .. cursor.track .. '].devices[1].parameters[5]'
  else
    return 'renoise.song().tracks[' .. cursor.track .. '].devices[1].parameters[2]'
  end
end


function pre_post_value(cursor, state)
  return pre_post_p(cursor, state)
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
  local t = renoise.song().tracks[track]
  if t == nil then return end
  local d = t.devices[device]
  if d == nil then return end
  return d.parameters[param]
end

