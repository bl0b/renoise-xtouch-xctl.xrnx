function base(xtouch, state)
  local schema = table.create {
    assign = {
      -- PRE / POST
      { xtouch = 'xtouch.flip,press',
        callback = function(cursor, state)
          renoise.app().window.mixer_view_post_fx = not renoise.app().window.mixer_view_post_fx
        end,
        description = "Toggle Pre/Post"
      },
      { obs = 'renoise.app().window.mixer_view_post_fx_observable -- flip led',
        value = function(c, s) return renoise.app().window.mixer_view_post_fx end,
        to_led = function(c, s, v) return v and 2 or 0 end,
        immediate = true,
        led = xtouch.flip.led },
      { renoise = 'renoise.app().window.mixer_view_post_fx_observable', frame = 'update' }, --xtouch.flip.led.value = renoise.app().window.mixer_view_post_fx and 2 or 0 end },
      -- EMABLE / DISABLE LED HACK
      { obs = '(xtouch.vu_enabled)', value = function(c, s) return xtouch.vu_enabled end, led = xtouch.global_view.led, to_led = function(cursor, state, v) return v.value and 2 or 0 end },
      { xtouch = 'xtouch.global_view,press',
        frame = 'update',
        before = function(cursor, state) xtouch.vu_enabled.value = not xtouch.vu_enabled.value end,
        description = "Toggle VU meters"
      },
      -- MAIN FADER
      { fader = 'xtouch.channels.main.fader',
        obs = function(cursor, state) return 'renoise.song():track(' .. master_track_index() .. ').' .. (renoise.app().window.mixer_view_post_fx and 'postfx_volume' or 'prefx_volume') end,
        value = function(cursor, state) return pre_post_value({track = master_track()}, state) end,
        description = "Main volume"
      },
      -- WRAPPED PATTERN EDIT MODE TOGGLE
      { xtouch = 'xtouch.scrub,press', callback = function(cursor, state) renoise.song().transport.wrapped_pattern_edit = not renoise.song().transport.wrapped_pattern_edit end, description = "Toggle wrapped pattern edit" },
      { obs = function(cursor, state) return 'renoise.song().transport.wrapped_pattern_edit_observable' end,
        value = function(cursor, state) return renoise.song().transport.wrapped_pattern_edit end,
        led = xtouch.scrub.led
      },
      -- RECALL VIEW PRESETS
      { xtouch = 'xtouch.midi_tracks,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR end, description = "View Pattern Editor" },
      { xtouch = 'xtouch.inputs,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER end, description = "View Mixer" },
      { xtouch = 'xtouch.audio_tracks,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR end, description = "View Phrase Editor" },
      { xtouch = 'xtouch.audio_inst,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES end, description = "View Keyzones" },
      { xtouch = 'xtouch.aux,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR end, description = "View Sample Editor" },
      { xtouch = 'xtouch.buses,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION end, description = "View Instrument Modulation" },
      { xtouch = 'xtouch.outputs,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS end, description = "View Instrument Effects" },
      { xtouch = 'xtouch.user,press', callback = function() renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR end, description = "View Plugin" },
      { led = xtouch.midi_tracks.led, obs = 'renoise.app().window.active_middle_frame_observable -- 1', immediate = true, value = function(c, s) return renoise.app().window.active_middle_frame end,
        to_led = function(c, s, v) return v == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR and 2 or 0 end
      },
      { led = xtouch.inputs.led, obs = 'renoise.app().window.active_middle_frame_observable -- 2', immediate = true, value = function(c, s) return renoise.app().window.active_middle_frame end,
        to_led = function(c, s, v) return v == renoise.ApplicationWindow.MIDDLE_FRAME_MIXER and 2 or 0 end
      },
      { led = xtouch.audio_tracks.led, obs = 'renoise.app().window.active_middle_frame_observable -- 3', immediate = true, value = function(c, s) return renoise.app().window.active_middle_frame end,
        to_led = function(c, s, v) return v == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR and 2 or 0 end
      },
      { led = xtouch.audio_inst.led, obs = 'renoise.app().window.active_middle_frame_observable -- 4', immediate = true, value = function(c, s) return renoise.app().window.active_middle_frame end,
        to_led = function(c, s, v) return v == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES and 2 or 0 end
      },
      { led = xtouch.aux.led, obs = 'renoise.app().window.active_middle_frame_observable -- 5', immediate = true, value = function(c, s) return renoise.app().window.active_middle_frame end,
        to_led = function(c, s, v) return v == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR and 2 or 0 end
      },
      { led = xtouch.buses.led, obs = 'renoise.app().window.active_middle_frame_observable -- 6', immediate = true, value = function(c, s) return renoise.app().window.active_middle_frame end,
        to_led = function(c, s, v) return v == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION and 2 or 0 end
      },
      { led = xtouch.outputs.led, obs = 'renoise.app().window.active_middle_frame_observable -- 7', immediate = true, value = function(c, s) return renoise.app().window.active_middle_frame end,
        to_led = function(c, s, v) return v == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS and 2 or 0 end
      },
      { led = xtouch.user.led, obs = 'renoise.app().window.active_middle_frame_observable -- 8', immediate = true, value = function(c, s) return renoise.app().window.active_middle_frame end,
        to_led = function(c, s, v) return v == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR and 2 or 0 end
      },
      -- ENTER FRAMES
      { obs = '(xtouch.current_page) -- 1', immediate = true, led = xtouch.encoder_assign.pan.led, value = function(c, s) return xtouch.current_page.value end, to_led = function(c, s, v) return v == 'Mix' and 2 or 0 end },
      { obs = '(xtouch.current_page) -- 2', immediate = true, led = xtouch.encoder_assign.plugin.led, value = function(c, s) return xtouch.current_page.value end, to_led = function(c, s, v) return v == 'Devices' and 2 or v == 'DevicesWidth' and 1 or 0 end },
      { xtouch = 'xtouch.encoder_assign.plugin,press', page = 'Devices' },
      { xtouch = 'xtouch.encoder_assign.pan,press', page = 'Mix' },
      -- { renoise = 'state.current_schema', immediate = true,
      --   callback = function(cursor, state)
      --     -- print("current_schema", state.current_schema.value, state.current_schema.value == 'mixer_frame', state.current_schema.value == 'device_frame')
      --     xtouch.encoder_assign.pan.led.value = 0
      --     xtouch.encoder_assign.plugin.led.value = 0
      --     xtouch.encoder_assign.pan.led.value = (state.current_schema.value == 'mixer_frame' and 2 or 0)
      --     xtouch.encoder_assign.plugin.led.value = (state.current_schema.value == 'device_frame' and 2 or (state.current_schema.value == 'param_frame' and 1 or 0))
      --   end
      -- },

      -- REFRESH CONDITIONS
      -- { renoise = 'renoise.song().tracks_observable', frame = 'update', callback = function() end }
    }
  }

  plug_schema(schema, modifier_support(xtouch))
  plug_schema(schema, transport(xtouch))

  return schema
end
