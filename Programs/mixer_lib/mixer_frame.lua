local last_playpos = nil

local hilighted_tracks = {}

function mixer_frame(xtouch, state)
  local frame_channels = false and {1, 2} or {1, 2, 3, 4, 5, 6, 7, 8}
  local schema = table.create {
    setup = function(cursor, state) end,
    teardown = function(cursor, state)
      for i = 1, 8 do xtouch:untap(i) end
    end,
    assign = {
      -- FRANE CONTROL
      { xtouch = 'xtouch.channel.left,press', cursor_step = -1 },
      { xtouch = 'xtouch.channel.right,press', cursor_step = 1 },
      { xtouch = 'xtouch.bank.left,press', cursor_step = -8 },
      { xtouch = 'xtouch.bank.right,press', cursor_step = 8 },
      { renoise = 'renoise.tool().app_idle_observable -- song pos', callback = function(cursor, state)
          if renoise.song().transport.playing then
            local playpos = renoise.song().transport.playback_pos
            if playpos ~= last_playpos then
              xtouch:send_lcd_string(1, string.format("P ----%03d%03d", playpos.sequence, playpos.line))
              last_playpos = playpos
            end
          else
            local playpos = renoise.song().transport.edit_pos
            if playpos ~= last_playpos then
              xtouch:send_lcd_string(1, string.format("E ----%03d%03d", playpos.sequence, playpos.line))
              last_playpos = playpos
            end
          end
        end
      },
      { renoise = 'renoise.song().transport.playing_observable', callback = function(c, s) last_playpos = 0 end },
      { renoise = 'renoise.song().tracks_observable', frame = 'update' },
    },
    frame = {
      name = 'track',
      before = function()
        if xtouch.program_config.hilight_tracks.value then
          local s = renoise.song()
          if xtouch.program_config.hilight_absolute.value then
            for i = 1, #s.tracks do s:track(i).color_blend = 0 end
          else
            for t, b in pairs(hilighted_tracks) do
              s:track(t).color_blend = b
            end
          end
        end
        hilighted_tracks = {}
      end,
      after = function(channels, values, start, state)
        if xtouch.program_config.hilight_tracks.value then
          local s = renoise.song()
          local tracks = all_usable_track_indices()
          local hl = xtouch.program_config.hilight_level.value
          if xtouch.program_config.hilight_absolute.value then
            for i = start, start + #channels - 1 do
              local t = s:track(tracks[i])
              t.color_blend = hl
            end
          else
            local j = start
            for i = start, start + #channels - 1 do
              local t = s:track(tracks[i])
              local b = t.color_blend
              hilighted_tracks[j] = b
              if b > 50 then
                b = b - hl
              else
                b = b + hl
              end
              if b < 0 then b = 0 end
              if b > 100 then b = 100 end
              t.color_blend = b
              j = j + 1
            end
          end
        end
      end,
      values = function(cursor, state) return all_usable_tracks() end,
      channels = frame_channels,
      assign = {
        -- { group = {
            -- FADER
            { fader = 'xtouch.channels[cursor.channel].fader',
              obs = pre_post_obs,
              value = pre_post_value,
              to_fader = function(cursor, state, value) return to_fader_device_param(xtouch, cursor.track:device(1), renoise.app().window.mixer_view_post_fx and 5 or 2, value) end,
              from_fader = function(cursor, state, value) return from_fader_device_param(xtouch, cursor.track:device(1), renoise.app().window.mixer_view_post_fx and 5 or 2, value) end,
              description = "Pre/Post volume" },
            -- SELECT
            { obs = function(c, s) return 'renoise.song().selected_track_observable -- select ' .. c.channel end,
              led = 'xtouch.channels[cursor.channel].select.led',
              value = function(cursor, state)
                -- print('select led', cursor.channel, renoise.song().selected_track, cursor.track)
                return rawequal(renoise.song().selected_track, cursor.track)
              end,
              to_led = function(cursor, state, value) return value and 2 or 0 end,
              immediate = true
            },
            { xtouch = 'xtouch.channels[cursor.channel].select,press',
              callback = function(cursor, state)
                renoise.song().selected_track_index = (function()
                  for i = 1, #renoise.song().tracks do if rawequal(renoise.song():track(i), cursor.track) then return i end end
                end)()
              end,
              description = "Select track"
            },
            -- VU LEDS
            { vu = 'cursor.channel',
              track = 'cursor.track',
              right_of = function(cursor, state) return cursor.track:device(renoise.app().window.mixer_view_post_fx and #cursor.track.devices or 1) end,
              post = function(cursor, state) return renoise.app().window.mixer_view_post_fx end,
              description = "Pre/Post signal level"
            },
            -- SCREEN
            { obs = 'cursor.track.name_observable',
              scribble = function(cursor, state)
                local t = cursor.track
                return {
                  id = 'track name',
                  channel = cursor.channel,
                  line1 = strip_vowels(t.group_parent and t.group_parent.name or ''),
                  line2 = strip_vowels(t.name),
                  inverse = true,
                  color = {t.color[1], t.color[2], t.color[3]}
                }
              end,
              immediate = true,
              description = "Track name"
            },
            { obs = 'renoise.app().window.mixer_view_post_fx and cursor.track.postfx_volume.value_observable or cursor.track.prefx_volume.value_observable',
              scribble = function(cursor, state)
                local p = renoise.app().window.mixer_view_post_fx and cursor.track.postfx_volume or cursor.track.prefx_volume
                return {id = 'volume popup', channel = cursor.channel, line2 = format_value(p.value_string), ttl = xtouch.program_config.popup_duration.value}
              end,
            }, 
            { obs = 'renoise.app().window.mixer_view_post_fx and cursor.track.postfx_panning.value_observable or cursor.track.prefx_panning.value_observable',
              scribble = function(cursor, state)
                local p = renoise.app().window.mixer_view_post_fx and cursor.track.postfx_panning or cursor.track.prefx_panning
                return {id = 'panning popup', channel = cursor.channel, line1 = format_value(p.value_string), ttl = xtouch.program_config.popup_duration.value}
              end,
            }, 
            -- MUTE
            { xtouch = 'xtouch.channels[cursor.channel].mute,press',
              callback = function(cursor, state) cursor.track.mute_state = 4 - cursor.track.mute_state end,
              description = "Mute track"
            },
            { obs = 'cursor.track.mute_state_observable',
              value = function(cursor, state) return cursor.track.mute_state end,
              led = 'xtouch.channels[cursor.channel].mute.led',
              to_led = function(cursor, state, v) return v == 3 and 2 or 0 end
            },
            -- SOLO
            { xtouch = 'xtouch.channels[cursor.channel].solo,press',
              callback = function(cursor, state) cursor.track.solo_state = not cursor.track.solo_state end,
              description = "Solo track"
            },
            { obs = 'cursor.track.solo_state_observable',
              value = function(cursor, state) return cursor.track.solo_state end,
              led = 'xtouch.channels[cursor.channel].solo.led',
              to_led = function(cursor, state, v) return v and 2 or 0 end,
            }
          }
        -- }
      -- },
      -- refresh_on = function(cursor, state) return 'renoise.song().tracks_observable' end
    }
  }

  plug_schema(schema, pot_and_leds_panning(xtouch))

  return schema
end
