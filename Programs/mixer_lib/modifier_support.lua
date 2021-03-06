function modifier_support(xtouch, state)
  return table.create({
    assign = {
      { xtouch = 'xtouch.modify.shift,press', callback = function(c, state) state.modifiers.shift.value = true end, description = "Shift modifier" },
      { xtouch = 'xtouch.modify.shift,release', callback = function(c, state) state.modifiers.shift.value = false end, no_description = true },
      { led = xtouch.modify.shift.led, obs = 'state.modifiers.shift', value = function(c, s) return s.modifiers.shift.value end },
      
      { xtouch = 'xtouch.modify.option,press', callback = function(c, state) state.modifiers.option.value = true end, description = "Option modifier" },
      { xtouch = 'xtouch.modify.option,release', callback = function(c, state) state.modifiers.option.value = false end, no_description = true },
      { led = xtouch.modify.option.led, obs = 'state.modifiers.option', value = function(c, s) return s.modifiers.option.value end },
      
      { xtouch = 'xtouch.modify.alt,press', callback = function(c, state) state.modifiers.alt.value = true end, description = "Alt modifier" },
      { xtouch = 'xtouch.modify.alt,release', callback = function(c, state) state.modifiers.alt.value = false end, no_description = true },
      { led = xtouch.modify.alt.led, obs = 'state.modifiers.alt', value = function(c, s) return s.modifiers.alt.value end },
      
      { xtouch = 'xtouch.modify.control,press', callback = function(c, state) state.modifiers.control.value = true end, description = "Control modifier" },
      { xtouch = 'xtouch.modify.control,release', callback = function(c, state) state.modifiers.control.value = false end, no_description = true },
      { led = xtouch.modify.control.led, obs = 'state.modifiers.control', value = function(c, s) return s.modifiers.control.value end }
    },
  })
end
