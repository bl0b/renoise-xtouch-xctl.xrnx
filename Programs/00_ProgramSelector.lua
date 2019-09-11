local backup_solo_led
local current_program = -1
local active_program = -1
local selecting = false
local X

--local backup_lcd = {
--  a = {l = 0, r = 0},
--  h = {l = 0, m = 0, r = 0},
--  m = {l = 0, r = 0},
--  s = {l = 0, r = 0},
--  t = {l = 0, m = 0, r = 0}
--}


--function backup_lcd_state()
--  backup_lcd.a.l = X.lcd.assignment.left
--  backup_lcd.a.m = X.lcd.assignment.right
--  backup_lcd.h.r = X.lcd.bars_hours.left
--  backup_lcd.h.l = X.lcd.bars_hours.middle
--  backup_lcd.h.r = X.lcd.bars_hours.right
--  backup_lcd.m.l = X.lcd.beats_minutes.left
--  backup_lcd.m.r = X.lcd.beats_minutes.right
--  backup_lcd.s.l = X.lcd.subdiv_seconds.left
--  backup_lcd.s.r = X.lcd.subdiv_seconds.right
--  backup_lcd.t.l = X.lcd.ticks_frames.left
--  backup_lcd.t.m = X.lcd.ticks_frames.middle
--  backup_lcd.t.r = X.lcd.ticks_frames.right
--end


--function restore_lcd_state()
--  X.lcd.assignment.left = backup_lcd.a.l
--  X.lcd.assignment.right = backup_lcd.a.m
--  X.lcd.bars_hours.left = backup_lcd.h.r
--  X.lcd.bars_hours.middle = backup_lcd.h.l
--  X.lcd.bars_hours.right = backup_lcd.h.r
--  X.lcd.beats_minutes.left = backup_lcd.m.l
--  X.lcd.beats_minutes.right = backup_lcd.m.r
--  X.lcd.subdiv_seconds.left = backup_lcd.s.l
--  X.lcd.subdiv_seconds.right = backup_lcd.s.r
--  X.lcd.ticks_frames.left = backup_lcd.t.l
--  X.lcd.ticks_frames.middle = backup_lcd.t.m
--  X.lcd.ticks_frames.right = backup_lcd.t.r
--end


function jog_program(event, widget)
  -- print('jog_program', event, widget.path, widget.delta)
  if widget.delta.value == 0 or not selecting then
    return false
  end
  local delta = widget.delta.value
  if delta > 64 then
    delta = 64 - delta
  end
  current_program = current_program + delta
  if current_program < 1 then
    current_program = 1
  elseif current_program > #X.programs then
    current_program = #X.programs
  end
  -- print('current_program =', current_program)
  show_current_program()
  return true
end


function show_current_program()
  if current_program < 1 then
    X:send_lcd_string(1, 'noprogram')
  else
    X:send_lcd_string(1, string.format("%02d%s", current_program, X.programs[current_program].name))
  end
end


function start_selection()
    backup_solo_led = X.solo_led.value
    X.solo_led.value = 2
--    backup_lcd()
    show_current_program()
    selecting = true
end


function end_selection()
  -- print("END SELECTION")
    selecting = false
    X.solo_led.value = backup_solo_led
    if current_program > 0 and current_program <= #X.programs then
      -- if active_program ~= -1 then
--        restore_lcd()
        -- X.programs[active_program].uninstall(X)
      -- end
      -- X.programs[current_program].install(X)
      X:select_program(current_program)

      active_program = current_program
    end
end


function toggle_selection(event, widget)
--  if event ~= 'long_press' then
--    return false
--  end
  if selecting then
    end_selection()
  else
    start_selection()
  end
end


return function(xtouch)
  X = xtouch
  X:on(X.transport.jog_wheel, 'delta', jog_program)
  X:on(X.display, 'long_press', toggle_selection)
  -- print("Installed program selector.")
end