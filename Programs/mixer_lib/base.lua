function foot_switch_1(event, invert, toggle)
  if invert then
    event = event == 'press' and 'release' or 'press'
  end
  local s = renoise.song()
  local t = s.transport
  if toggle then
    if event == 'press' then
      if t.playing then t:stop() t:stop() else t:start(renoise.Transport.PLAYMODE_CONTINUE_PATTERN) end
    end
  else
    if event == 'press' then
      if not t.playing then t:start(renoise.Transport.PLAYMODE_CONTINUE_PATTERN) end
    else
      if t.playing then t:stop() t:stop() end
    end
  end
end


function foot_switch_2(event, invert, toggle)
  if invert then
    event = event == 'press' and 'release' or 'press'
  end
  local s = renoise.song()
  local t = s.transport
  if toggle then
    if event == 'press' then
      t.edit_mode = not t.edit_mode
    end
  else
    if event == 'press' then
      t.edit_mode = true
    else
      t.edit_mode = false
    end
  end
end



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
      { obs = '(xtouch.current_page) -- 3', immediate = true, led = xtouch.encoder_assign.send.led, value = function(c, s) return xtouch.current_page.value end, to_led = function(c, s, v) return v == 'Sends' and 2 or 0 end },
      { obs = '(xtouch.current_page) -- 4', immediate = true, led = xtouch.encoder_assign.track.led, value = function(c, s) return xtouch.current_page.value end, to_led = function(c, s, v) return v == 'Automation' and 2 or 0 end },
      { xtouch = 'xtouch.encoder_assign.track,press', page = 'Automation' },
      { xtouch = 'xtouch.encoder_assign.plugin,press', page = 'Devices' },
      { xtouch = 'xtouch.encoder_assign.pan,press', page = 'Mix' },
      { xtouch = 'xtouch.encoder_assign.send,press', page = 'Sends' },
      { xtouch = 'xtouch.foot_switch_1,press',
        callback = function()
          foot_switch_1('press', xtouch.program_config.fs1_invert.value, xtouch.program_config.fs1_is_toggle.value)
        end,
        description = "Play/Stop (continue)"
      },
      { xtouch = 'xtouch.foot_switch_1,release',
        callback = function()
          foot_switch_1('release', xtouch.program_config.fs1_invert.value, xtouch.program_config.fs1_is_toggle.value)
        end,
        description = "Play/Stop (continue)"
      },
      { xtouch = 'xtouch.foot_switch_2,press',
        callback = function()
          foot_switch_2('press', xtouch.program_config.fs2_invert.value, xtouch.program_config.fs2_is_toggle.value)
        end,
        description = "Toggle edit mode"
      },
      { xtouch = 'xtouch.foot_switch_2,release',
        callback = function()
          foot_switch_2('release', xtouch.program_config.fs2_invert.value, xtouch.program_config.fs2_is_toggle.value)
        end,
        description = "Toggle edit mode"
      },
    }
  }

  plug_schema(schema, modifier_support(xtouch))
  plug_schema(schema, transport(xtouch))

  return schema
end
