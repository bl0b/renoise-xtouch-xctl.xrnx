local track_move_by = function(n)
  return function(cursor, state)
    local tracks = all_usable_track_indices()
    local s = renoise.song()
    local ti = table.find(tracks, s.selected_track_index)
    if ti == nil then
      local best = 100000
      for i = 1, #tracks do
        local delta = math.abs(tracks[i] - s.selected_track_index)
        if delta < best then
          ti, best = i, delta
        end
      end
    end

    if n < 0 then ti = ti + #tracks + n else ti = ti + n end
    s.selected_track_index = 1 + math.mod(ti - 1, #tracks)
  end
end

function transport(xtouch, state)
  local last_jog_wheel_timestamp = nil
  return table.create({
    assign = {
      { xtouch = 'xtouch.transport.forward,press',   callback = function() transport_ofs(1) xtouch.transport.forward.led.value = 2 end, description = "Forward by one pattern" },
      { xtouch = 'xtouch.transport.rewind,press',   callback = function() transport_ofs(-1) xtouch.transport.rewind.led.value = 2 end, description = "Rewind by one pattern" },
      { xtouch = 'xtouch.transport.forward,release', callback = function() xtouch.transport.forward.led.value = 0 end, no_description = true },
      { xtouch = 'xtouch.transport.rewind,release', callback = function() xtouch.transport.rewind.led.value = 0 end, no_description = true },
      { xtouch = 'xtouch.transport.stop,press',   callback = function() renoise.song().transport.playing = false end, description = "Stop" },
      { xtouch = 'xtouch.transport.play,press',   callback = function() renoise.song().transport.playing = true end, description = "Play" },
      { xtouch = 'xtouch.transport.record,press',   callback = function() renoise.song().transport.edit_mode = not renoise.song().transport.edit_mode end, description = "Toggle Edit Node" },

      { xtouch = 'xtouch.left,press', callback = track_move_by(-1), description = 'Select previous track' },
      { xtouch = 'xtouch.right,press', callback = track_move_by(1), description = 'Select next track' },
      { xtouch = 'xtouch.up,press', callback = function(cursor, state)
          local si = renoise.song().transport.edit_pos
          local max = renoise.song().transport.song_length.sequence
          si.sequence = 1 + math.mod(si.sequence + max - 2, max)
          renoise.song().transport.edit_pos = si
        end,
        description = 'Select previous pattern',
      },
      { xtouch = 'xtouch.down,press', callback = function(cursor, state)
          local si = renoise.song().transport.edit_pos
          local max = renoise.song().transport.song_length.sequence
          si.sequence = 1 + math.mod(si.sequence, max)
          renoise.song().transport.edit_pos = si
        end,
        description = 'Select next pattern',
      },

      { renoise = 'renoise.song().transport.edit_mode_observable', immediate = true, callback = function() xtouch.transport.record.led.value = renoise.song().transport.edit_mode and 2 or 0 end },
      { renoise = 'renoise.song().transport.playing_observable', immediate = true,
        callback = function()
          if renoise.song().transport.playing then
            xtouch.transport.stop.led.value = 0
            xtouch.transport.play.led.value = 2
          else
            xtouch.transport.stop.led.value = 2
            xtouch.transport.play.led.value = 0
          end
        end
      },
      { xtouch = 'xtouch.transport.jog_wheel,delta',
        callback = function()
          local timestamp = os.clock()
          local multiplier = 1
          if last_jog_wheel_timestamp then
            local delta_t = timestamp - last_jog_wheel_timestamp
            if delta_t < 0.005 then
              multiplier = renoise.song().transport.lpb * 8
            elseif delta_t < 0.010 then
              multiplier = renoise.song().transport.lpb * 4
            elseif delta_t < 0.025 then
              multiplier = renoise.song().transport.lpb * 2
            elseif delta_t < 0.05 then
              multiplier = renoise.song().transport.lpb * 1
            end
            -- print("jog wheel multiplier", xtouch.transport.jog_wheel.delta.value, last_jog_wheel_timestamp, timestamp, multiplier)
          end
          last_jog_wheel_timestamp = timestamp

          local song = renoise.song()
          local seq = song.sequencer
          local transport = song.transport
          local pos = transport.playing and transport.playback_pos or transport.edit_pos
          local max = transport.song_length
          pos.line = pos.line + (xtouch.transport.jog_wheel.delta.value * multiplier)

          local p = song:pattern(seq:pattern(pos.sequence))
          while pos.line > p.number_of_lines and pos.sequence < max.sequence do
            pos.line = pos.line - p.number_of_lines
            pos.sequence = pos.sequence + 1
            p = song:pattern(seq:pattern(pos.sequence))
          end
          while pos.line < 1 and pos.sequence > 1 do
            pos.sequence = pos.sequence - 1
            p = song:pattern(seq:pattern(pos.sequence))
            pos.line = pos.line + p.number_of_lines
          end
          if pos.sequence == 1 and pos.line < 1 then
            pos.line = 1
          end
          if pos.sequence >= max.sequence and pos.line >= max.line then
            pos.line = max.line
          end

          xpcall(function()
            if renoise.song().transport.playing then
              renoise.song().transport.playback_pos = pos
            else
              renoise.song().transport.edit_pos = pos
            end
          end, function(err) print(err) print(debug.traceback()) end)

          -- local len = renoise.song().transport.lpb * renoise.song().transport.song_length_beats
          -- local cur
          -- if renoise.song().transport.playing then
          --   cur = renoise.song().transport.lpb * renoise.song().transport.playback_pos_beats
          -- else
          --   cur = renoise.song().transport.lpb * renoise.song().transport.edit_pos_beats
          -- end
          -- cur = cur + (xtouch.transport.jog_wheel.delta.value * multiplier)
          -- if cur < 0 then cur = 0 end
          -- if cur >= len then cur = len end
          -- print(cur, len)
          -- pcall(function()
          --   if renoise.song().transport.playing then
          --     renoise.song().transport.playback_pos_beats = (cur + .1) / renoise.song().transport.lpb
          --   else
          --     renoise.song().transport.edit_pos_beats = (cur + .1) / renoise.song().transport.lpb
          --   end
          -- end)
        end,
        description = "Transport through entire song"
      },
    }
  })
end
