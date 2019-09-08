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
    description = "Program for mixing",

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
      current_device = 1
    },

    schemas = {
      mixer_frame = mixer_frame,
      device_frame = device_frame,
      device_frame_pan = device_frame_pan,
      device_frame_width = device_frame_width,
      param_frame = param_frame,
      base = base
    },

    pages = {
      Mix = {
        description = "Pre/Post Mix controls.",
        schemas = { 'base', 'mixer_frame' },
      },
      Devices = {
        description = "Map one device to each X-Touch channel in the selected track. Encoder selects parameter to edit. VUs visualize the gain structure of selected track. Press SHIFT to edit Width with encoder #1.",
        schemas = { 'base', 'device_frame', 'device_frame_pan' },
      },
      DevicesWidth = {
        description = "Devices page, but encoder #1 edits Width instead of Pre Volume. Only active while SHIFT is depressed.",
        schemas = { 'base', 'device_frame', 'device_frame_width' }
      },
      Params = {
        description = "Flat view of all parameters of the selected device in the selected track.",
        schemas = { 'base', 'param_frame' }
      }
    },

    startup = { 'base', 'mixer_frame' },
    startup_page = 'Mix'
  }
end
