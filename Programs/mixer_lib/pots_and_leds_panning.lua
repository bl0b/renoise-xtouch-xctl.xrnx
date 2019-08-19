function pot_and_leds_panning(xtouch, state)
  return table.create({
    frame = {
      assign = {
        { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].encoder,delta' end,
          callback = function(cursor, state, event, widget)
            local v
            if renoise.app().window.mixer_view_post_fx then
              v = renoise.song().tracks[cursor.track].postfx_panning.value
              v = v + widget.delta.value * 0.01
              if v < 0 then v = 0 end
              if v > 1 then v = 1 end
              renoise.song().tracks[cursor.track].postfx_panning.value = v
            else
              v = renoise.song().tracks[cursor.track].prefx_panning.value
              v = v + widget.delta.value * 0.01
              if v < 0 then v = 0 end
              if v > 1 then v = 1 end
              renoise.song().tracks[cursor.track].prefx_panning.value = v
            end
          end
        },
        { obs = function(cursor, state)
            if renoise.app().window.mixer_view_post_fx then
              return 'renoise.song().tracks[' .. cursor.track .. '].postfx_panning'
            else
              return 'renoise.song().tracks[' .. cursor.track .. '].prefx_panning'
            end
          end,
          value = function(cursor, state)
            if renoise.app().window.mixer_view_post_fx then
              return renoise.song().tracks[cursor.track].postfx_panning.value
            else
              return renoise.song().tracks[cursor.track].prefx_panning.value
            end
          end,
          led = function(cursor, state) return xtouch.channels[cursor.channel].encoder.led end,
          to_led = led_center_strip
        },
      }
    }
  })
end
