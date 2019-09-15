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
require 'Programs/mixer_lib/send_frame'
require 'Programs/mixer_lib/base'

return function(xtouch, state)
  return table.create {
    name = 'Mixer',
    number = 1,
    description = "Generic mix-oriented mappings. 3 levels of operation:\n- mix tracks\n- tweak plugin parameters in selected track\n- tweak all parameters in selected device in selected track.",

    config = renoise.Document.create('MixerConfiguration') {
      show_sends_in_device_frame = renoise.Document.ObservableBoolean(true),
      popup_duration = renoise.Document.ObservableNumber(1.5),
      hilight_tracks = renoise.Document.ObservableBoolean(true),
      hilight_absolute = renoise.Document.ObservableBoolean(true),
      hilight_level = renoise.Document.ObservableNumber(20),
    },

    config_meta = {
      show_sends_in_device_frame = {
        label = 'Show Sends in Devices frame',
        tooltip = 'If disabled, hide Sends in the Devices page.\nThey are still accessible on their own in the Sends page.'
      },
      popup_duration = {
        label = 'Popup duration',
        tooltip = 'How long the value changes should remain visible on the scribble strips',
        min = .3,
        max = 3,
      },
      hilight_tracks = {
        label = 'Hilight tracks',
        tooltip = 'Use track color blend to hilight which tracks are currently mapped in the Mix page'
      },
      hilight_absolute = {
        label = 'Hilight mode',
        tooltip = 'Absolute mode will toggle blend level between 0 and hilight level.\nRelative mode will toggle between current blend level and current blend level ± hilight level, depending on the strength of the blend level.\nChoose Relative mode and a level of 0 to deactivate.',
        switch = {items = {'Relative', 'Absolute'}, values = {false, true}}
      },
      hilight_level = {
        label = 'Hilight level',
        tooltip = 'Amount by which to change the track color blend level when the track is mapped to an X-Touch channel in the Mix page',
        min = 0,
        max = 50,
      }
    },

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
      send_frame = send_frame,
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
      },
      Sends = {
        description = "Configure sends in the selected track.",
        schemas = { 'base', 'send_frame' },
      },
    },

    startup = { 'base', 'mixer_frame' },
    startup_page = 'Mix'
  }
end
