local led_off = function(led_name)
  return {
    led = 'xtouch.automation.' .. led_name .. '.led',
    obs = 'dummy -- ' .. led_name .. ' off',
    value = function() end, to_led = function() return 0 end, immediate = true
  }
end

function automation_leds_off(xtouch)
  return { assign = { led_off('write'), led_off('read_off'), led_off('trim'), led_off('group'), led_off('latch'), led_off('touch') } }
end