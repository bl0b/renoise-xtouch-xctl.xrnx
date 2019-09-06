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
          local multiplier = 1.0 / renoise.song().transport.lpb
          if last_jog_wheel_timestamp then
            local delta_t = timestamp - last_jog_wheel_timestamp
            if delta_t < 0.005 then
              multiplier = 8
            elseif delta_t < 0.010 then
              multiplier = 4
            elseif delta_t < 0.025 then
              multiplier = 2
            elseif delta_t < 0.05 then
              multiplier = 1
            end
            -- print("jog wheel multiplier", xtouch.transport.jog_wheel.delta.value, last_jog_wheel_timestamp, timestamp, multiplier)
          end
          last_jog_wheel_timestamp = timestamp
          local len = renoise.song().transport.song_length_beats
          local cur
          if renoise.song().transport.playing then
            cur = renoise.song().transport.playback_pos_beats
          else
            cur = renoise.song().transport.edit_pos_beats
          end
          cur = cur + (xtouch.transport.jog_wheel.delta.value * multiplier)
          if cur < 0 then cur = 0 end
          if cur >= len then cur = len - (1.0 / renoise.song().transport.lpb) end
          if renoise.song().transport.playing then
            renoise.song().transport.playback_pos_beats = cur
          else
            renoise.song().transport.edit_pos_beats = cur
          end
        end,
        description = "Transport through entire song"
      },
    }
  })
end
