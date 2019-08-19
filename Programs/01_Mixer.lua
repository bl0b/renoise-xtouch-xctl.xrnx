--
-- Mixer mapping for the X-Touch
-- author: Damien Leroux
--

require 'Programs/mixer_lib/utility'
require 'Programs/mixer_lib/modifier_support'
require 'Programs/mixer_lib/transport'
require 'Programs/mixer_lib/pots_and_leds_panning'
require 'Programs/mixer_lib/param_frame'
require 'Programs/mixer_lib/device_frame'
require 'Programs/mixer_lib/mixer_frame'
require 'Programs/mixer_lib/base'

return function(xtouch, state)
  return table.create {
    name = 'Mixer',
    number = 1,

    state = renoise.Document.create('mixer_state') {
      -- current_schema = renoise.Document.ObservableString(''),
      modifiers = {
        shift = renoise.Document.ObservableBoolean(false),
        option = renoise.Document.ObservableBoolean(false),
        control = renoise.Document.ObservableBoolean(false),
        alt = renoise.Document.ObservableBoolean(false),
      },
      current_param = {1, 1, 1, 1, 1, 1, 1, 1},
      current_track = renoise.song().selected_track_index,
      current_device = 1,
    },

    schemas = {
      mixer_frame = mixer_frame,
      device_frame = device_frame,
      param_frame = param_frame,
      base = base
    },

    startup = { 'base', 'mixer_frame' }
  }
end
