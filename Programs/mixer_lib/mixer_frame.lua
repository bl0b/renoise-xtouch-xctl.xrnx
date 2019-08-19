local last_playpos = nil

function mixer_frame(xtouch, state)
  local frame_channels = false and {1, 2} or {1, 2, 3, 4, 5, 6, 7, 8}
  local schema = table.create {
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
      values = function(cursor, state)
        local ret, trk = table.create(), renoise.song().tracks
        local M, S = renoise.Track.TRACK_TYPE_MASTER, renoise.Track.TRACK_TYPE_SEND
        for i = 1, #trk do
          if trk[i].type ~= M and (trk[i].type ~= S or string.sub(trk[i].name, 1, 8) ~= 'XT LED #') then
            ret:insert(i)
          end
        end
        return ret
      end,
      channels = frame_channels,
      assign = {
        -- { group = {
            -- FADER
            { fader = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].fader' end, obs = pre_post_obs, value = pre_post_value },
            -- SELECT
            { obs = function(cursor, state) return 'renoise.song().selected_track_index_observable -- ' .. cursor.channel end,
              led = function(cursor, state) return xtouch.channels[cursor.channel].select.led end,
              value = function(cursor, state) return renoise.song().selected_track_index end,
              to_led = function(cursor, state)
                local is_current = renoise.song().selected_track_index == cursor.track
                if cursor.channel == 1 then
                  return is_current and 2 or renoise.song().selected_track_index < cursor.track and 1 or 0
                elseif cursor.channel == 8 then
                  return is_current and 2 or renoise.song().selected_track_index > cursor.track and 1 or 0
                else
                  return is_current and 2 or 0
                end
              end
            },
            { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].select,press' end,
              callback = function(cursor, state) renoise.song().selected_track_index = cursor.track end
            },
            -- VU LEDS
            { vu = function(cursor, state) return cursor.channel end,
              track = function(cursor, state) return cursor.track end,
              at = function(cursor, state) return not renoise.app().window.mixer_view_post_fx and 2 or nil end,
              post = function(cursor, state) return renoise.app().window.mixer_view_post_fx end
            },
            -- SCREEN
            { screen = function(cursor, state) return xtouch.channels[cursor.channel].screen end, render = render_track_name,
              trigger = function(cursor, state) return 'renoise.song().tracks[' .. cursor.track .. '].name_observable' end,
              value = function(cursor, state) return renoise.song().tracks[cursor.track] end,
            },
            -- MUTE
            { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].mute,press' end,
              callback = function(cursor, state) renoise.song().tracks[cursor.track].mute_state = 4 - renoise.song().tracks[cursor.track].mute_state end,
            },
            { obs = function(cursor, state) return 'renoise.song().tracks[' .. cursor.track .. '].mute_state_observable' end,
              value = function(cursor, state) return renoise.song().tracks[cursor.track].mute_state end,
              led = function(cursor, state) return xtouch.channels[cursor.channel].mute.led end,
              to_led = function(cursor, state, v) return v == 3 and 2 or 0 end
            },
            -- SOLO
            { xtouch = function(cursor, state) return 'xtouch.channels[' .. cursor.channel .. '].solo,press' end,
              callback = function(cursor, state) renoise.song().tracks[cursor.track].solo_state = not renoise.song().tracks[cursor.track].solo_state end,
            },
            { obs = function(cursor, state) return 'renoise.song().tracks[' .. cursor.track .. '].solo_state_observable' end,
              value = function(cursor, state) return renoise.song().tracks[cursor.track].solo_state end,
              led = function(cursor, state) return xtouch.channels[cursor.channel].solo.led end
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
