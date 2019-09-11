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
      { renoise = 'renoise.tool().app_idle_observable', callback = function(cursor, state)
          if renoise.song().transport.playing then
            local playpos = renoise.song().transport.playback_pos
            if playpos ~= last_playpos then
              xtouch:send_lcd_string(1, string.format("------%03d%03d", playpos.sequence, playpos.line))
              last_playpos = playpos
            end
          else
            local playpos = renoise.song().transport.edit_pos
            if playpos ~= last_playpos then
              xtouch:send_lcd_string(1, string.format("------%03d%03d", playpos.sequence, playpos.line))
              last_playpos = playpos
            end
          end
        end
      },
    },
    frame = {
      name = 'track',
      before = function()
        for t, b in pairs(hilighted_tracks) do
          renoise.song():track(t).color_blend = b
        end
        hilighted_tracks = {}
      end,
      after = function(channels, values, start, state)
        for i = start, start + #channels - 1 do
          local t = renoise.song():track(i)
          local b = t.color_blend
          hilighted_tracks[i] = b
          b = b + 20
          if b > 100 then b = 100 end
          t.color_blend = b
        end
      end,
      values = function(cursor, state)
        local ret = table.create()
        local M, S = renoise.Track.TRACK_TYPE_MASTER, renoise.Track.TRACK_TYPE_SEND
        for i = 1, #renoise.song().tracks do
          local trk = renoise.song():track(i)
          if trk.type ~= M and (trk.type ~= S or string.sub(trk.name, 1, 8) ~= 'XT LED #') then
            ret:insert(trk)
          end
        end
        return ret
      end,
      channels = frame_channels,
      assign = {
        -- { group = {
            -- FADER
            { fader = 'xtouch.channels[cursor.channel].fader', obs = pre_post_obs, value = pre_post_value, description = "Pre/Post volume" },
            -- SELECT
            { obs = 'renoise.song().selected_track_index_observable',
              led = 'xtouch.channels[cursor.channel].select.led',
              value = function(cursor, state) return rawequal(renoise.song().selected_track, cursor.track) end,
              to_led = function(cursor, state, value) return value and 2 or 0 end
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
            { screen = 'xtouch.channels[cursor.channel].screen',
              trigger = 'cursor.track.name_observable',
              render = render_generic,
              value = function(cursor, state)
                return {
                  line1 = strip_vowels(cursor.track.group_parent and cursor.track.group_parent.name or ''),
                  line2 = strip_vowels(cursor.track.name),
                  inverse = true,
                  color = cursor.track.color
                }
              end,
              description = "Track name"
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
