function base(xtouch, state)
  local schema = table.create {
    assign = {
      -- PRE / POST
      { xtouch = 'xtouch.flip,press',
        callback = function(cursor, state)
          renoise.app().window.mixer_view_post_fx = not renoise.app().window.mixer_view_post_fx
          xtouch.flip.led.value = renoise.app().window.mixer_view_post_fx and 2 or 0
        end,
      },
      { renoise = 'renoise.app().window.mixer_view_post_fx_observable', frame = 'update' }, --xtouch.flip.led.value = renoise.app().window.mixer_view_post_fx and 2 or 0 end },
      -- EMABLE / DISABLE LED HACK
      { obs = '(xtouch.vu_enabled)', value = xtouch.vu_enabled, led = xtouch.global_view.led, to_led = function(cursor, state, v) return v.value and 2 or 0 end },
      { xtouch = 'xtouch.global_view,press', frame = 'update', callback = function(cursor, state) xtouch.vu_enabled.value = not xtouch.vu_enabled.value end },
      -- MAIN FADER
      { fader = 'xtouch.channels.main.fader',
        obs = function(cursor, state) return pre_post_obs({track = master_track()}, state) end,
        value = function(cursor, state) return pre_post_value({track = master_track()}, state) end,
      },
      -- WRAPPED PATTERN EDIT MODE TOGGLE
      { xtouch = 'xtouch.scrub,press', callback = function(cursor, state) renoise.song().transport.wrapped_pattern_edit = not renoise.song().transport.wrapped_pattern_edit end },
      { obs = function(cursor, state) return 'renoise.song().transport.wrapped_pattern_edit_observable' end,
        value = function(cursor, state) return renoise.song().transport.wrapped_pattern_edit end,
        led = xtouch.scrub.led
      },
      -- RECALL VIEW PRESETS
      { xtouch = 'xtouch.midi_tracks,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR end },
      { xtouch = 'xtouch.inputs,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER end },
      { xtouch = 'xtouch.audio_tracks,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR end },
      { xtouch = 'xtouch.audio_inst,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES end },
      { xtouch = 'xtouch.aux,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR end },
      { xtouch = 'xtouch.buses,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION end },
      { xtouch = 'xtouch.outputs,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS end },
      { xtouch = 'xtouch.user,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR end },
      { renoise = 'renoise.app().window.active_middle_frame_observable', immediate = true, callback = function(cursor, state)
          local f = renoise.app().window.active_middle_frame
          xtouch.midi_tracks.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR and 2 or 0
          xtouch.inputs.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_MIXER and 2 or 0
          xtouch.audio_tracks.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR and 2 or 0
          xtouch.audio_inst.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES and 2 or 0
          xtouch.aux.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR and 2 or 0
          xtouch.buses.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION and 2 or 0
          xtouch.outputs.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS and 2 or 0
          xtouch.user.led.value = f == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR and 2 or 0
        end
      },
      -- ENTER FRAMES
      { xtouch = 'xtouch.encoder_assign.plugin,press', schema = 'device_frame' },
      { xtouch = 'xtouch.encoder_assign.pan,press', schema = 'mixer_frame' },
      { renoise = 'state.current_schema', immediate = true, callback = function(cursor, state)
        -- print("current_schema", state.current_schema.value, state.current_schema.value == 'mixer_frame', state.current_schema.value == 'device_frame')
          xtouch.encoder_assign.pan.led.value = (state.current_schema.value == 'mixer_frame' and 2 or 0)
          xtouch.encoder_assign.plugin.led.value = (state.current_schema.value == 'device_frame' and 2 or 0) -- (state.current_schema.value == 'param_frame' and 1 or 0)
        end
      },

      -- REFRESH CONDITIONS
      { renoise = 'renoise.song().tracks_observable', frame = 'update', callback = function() end }
    }
  }

  plug_schema(schema, modifier_support(xtouch))
  plug_schema(schema, transport(xtouch))

  return schema
end
