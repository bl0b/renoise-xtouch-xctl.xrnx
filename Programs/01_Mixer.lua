local state
local xtouch

local trackvolpan_vol = {[false] = 2, [true] = 5}


function master_track()
  local s = renoise.song()
  for _, t in pairs(s.tracks) do
    if t.type == 2 then -- FIXME there's a constant somewhere
      return t
    end
  end
end


local assign_table = {}

function to_xtouch(source, event)
  local t = type(source)
  --oprint(source)
  return event ~= nil and (t == 'DocumentNode' and source.path ~= nil or t == 'string')
end

function unassign(source, event)
  if assign_table[{source, event}] ~= nil then
    return
  end
  print('unassign', source, event, assign_table[{source, event}])
  if to_xtouch(source, event) then
    xtouch:off(source, event)
  else
    source:remove_notifier(assign_table[{source, event}])
  end
end

function assign(source, event, callback)
  if callback == nil then
    callback = event
    event = nil
  end
  if assign_table[{source, event}] ~= nil then
    unassign(source)
  end
  assign_table[{source, event}] = callback
  if to_xtouch(source, event) then
    -- X-Touch binding
    print('binding on x-touch', source.path or source, event)
    xtouch:on(source, event, callback)
  elseif string.sub(type(source), 1, 10) == 'Observable' then
    print('binding on renoise')
    source:add_notifier(callback)
  else
    error("Can't find what to do for a " .. type(source) .. " for event " .. (event == nil and 'nil' or event))
  end
end

function clear_assigns()
  for source_event, _ in pairs(assign_table) do
    unassign(source_event[1], source_event[2])
  end
  assign_table = {}
end


function assign_tracks()
  local song = renoise.song()
  if song == nil then
    song = {tracks = {}}
  end
  for chan_num = 1, 8 do
    local track_num = chan_num + state.track_offset.value
    local t = song.tracks[track_num]
    local c = xtouch.channels[chan_num]
    if t ~= nil then
      assign(c.fader, 'move', function(event, widget)
        local value = math.db2fader(-48, 3, math.fader2db(-70, 10, c.fader.value.value))
        t.devices[1].parameters[trackvolpan_vol[state.post.value]] = value
      end)
      assign(t.devices[1].parameters[trackvolpan_vol[state.post.value]].value_observable, function()
        local value = math.db2fader(-70, 10, math.fader2db(-48, 3, c.fader.value.value))
        c.fader.value.value = value
      end)
      assign(c.mute, 'press', function()
        t.mute_state = ({3, 2, 1})[t.mute_state]
        c.mute.led.value = t.mute_state > 1 and 1 or 0
      end)
      xtouch:attach_VU_to_track(track_num, chan_num)
      c.screen.line2 = string.sub(t.name, 1, 7)
      c.screen.color = t.color
    else
      unassign(c.select, 'press')
      unassign(c.mute, 'press')
      unassign(c.solo, 'press')
      unassign(c.rec, 'press')
      xtouch:detach_vu(track_num)
      unassign(c.fader, 'move')
      c.screen.color = {0, 0, 0}
    end
    xtouch:send_strip(chan_num)
  end
end


function init_mixer()
  assign_tracks()
  assign(xtouch.bank.left, 'press', function() if state.track_offset.value < 8 then state.track_offset.value = 0 else state.track_offset.value = state.track_offset.value - 8 end end)
  assign(xtouch.bank.right, 'press', function() if state.track_offset.value > (#renoise.song().tracks - 8) then state.track_offset.value = #renoise.song().tracks - 8 else state.track_offset.value = state.track_offset.value + 8 end end)
  assign(xtouch.channel.left, 'press', function() if state.track_offset.value > 0 then state.track_offset.value = state.track_offset.value - 1 end end)
  assign(xtouch.channel.right, 'press', function() if state.track_offset.value < #renoise.song().tracks then state.track_offset.value = state.track_offset.value + 1 end end)
  assign(state.track_offset, assign_tracks)
end







return {
  name = 'Mixer',
  number = 1,
  install = function(x)
    xtouch = x
    clear_assigns()
    state = renoise.Document.create('mixer_state') {
      page_number = 1,
      track_offset = 0,
      post = false
    }
    init_mixer()
  end,
  uninstall = function(x)
  end
}
