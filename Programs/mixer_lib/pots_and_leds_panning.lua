function pot_and_leds_panning(xtouch, state)
  return table.create({
    frame = {
      assign = {
        { xtouch = 'xtouch.channels[cursor.channel].encoder,delta',
          callback = function(cursor, state, event, widget)
            local v
            if renoise.app().window.mixer_view_post_fx then
              v = cursor.track.postfx_panning.value
              v = v + widget.delta.value * 0.01
              if v < 0 then v = 0 end
              if v > 1 then v = 1 end
              cursor.track.postfx_panning.value = v
            else
              v = cursor.track.prefx_panning.value
              v = v + widget.delta.value * 0.01
              if v < 0 then v = 0 end
              if v > 1 then v = 1 end
              cursor.track.prefx_panning.value = v
            end
          end,
          description = "Pre/Post Panning"
        },
        { xtouch = 'xtouch.channels[cursor.channel].encoder,click',
          page = 'Devices',
          callback = function(cursor, state, event, widget)
            local s = renoise.song()
            for i = 1, #s.tracks do
              if rawequal(cursor.track, s:track(i)) then
                renoise.song().selected_track_index = i
                return
              end
            end
          end
        },
        { obs = function(cursor, state)
            if renoise.app().window.mixer_view_post_fx then
              return 'cursor.track.postfx_panning'
            else
              return 'cursor.track.prefx_panning'
            end
          end,
          value = function(cursor, state)
            if renoise.app().window.mixer_view_post_fx then
              return cursor.track.postfx_panning.value
            else
              return cursor.track.prefx_panning.value
            end
          end,
          led = 'xtouch.channels[cursor.channel].encoder.led',
          to_led = led_center_strip
        },
      }
    }
  })
end
