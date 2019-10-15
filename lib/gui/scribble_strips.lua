

-- Match a color to one in the X-Touch
-- X-Touch defines:
-- 0 turn off
-- 1 Red
-- 2 Green
-- 3 Yellow
-- 4 Blue
-- 5 Magenta
-- 6 Cyan
-- 7 White

local vb

function match_color_gui(r, g, b)
  local xtcol = {{255, 0, 0}, {0, 255, 0}, {255, 255, 0}, {0, 0, 255}, {255, 0, 255}, {0, 255, 255}, {255, 255, 255}}
  local best = 7
  local bestproj = 1000000
  if r == 0 and g == 0 and b == 0 then
    return {0, 0, 0}
  end
  for i = 1, #xtcol do
    local dr = (xtcol[i][1] - r)
    local dg = (xtcol[i][2] - g)
    local db = (xtcol[i][3] - b)
    dr = dr * dr
    dg = dg * dg
    db = db * db
    local proj = math.sqrt(dr + dg + db)
    if (proj < bestproj) then
      bestproj = proj
      best = i
    end
  end
  return xtcol[best]
end


function dim(c, brightness)
  return {c[1] * brightness, c[2] * brightness, c[3] * brightness}
end



function create_scribble_gui(strip, brightness_observable, screen_bang)
  local color = dim(match_color_gui(strip.color[1].value, strip.color[2].value, strip.color[3].value), brightness_observable.value)
  local line1 = vb:button { width = 50, color = color, text = strip.line1.value }
  local line2 = vb:button { width = 50, color = color, text = strip.line2.value }
  
  local update = function()
    local c = dim(match_color_gui(strip.color[1].value, strip.color[2].value, strip.color[3].value), brightness_observable.value)
    if c[1] == 0 and c[2] == 0 and c[3] == 0 then
      line1.text = ''
      line2.text = ''
      line1.color = {1, 1, 1}
      line2.color = {1, 1, 1}
    else
      line1.text = strip.line1.value:sub(1, 7)
      line2.text = strip.line2.value:sub(1, 7)
      line1.color = c
      line2.color = c
    end
  end

  brightness_observable:add_notifier(update)
  screen_bang:add_notifier(update)

  return vb:column { style = 'group',  line1, line2 }
end


local scribble_dialog = nil


function hide_strips_dialog(xtouch)
  if scribble_dialog and scribble_dialog.visible then scribble_dialog:close() end
end


function scribble_strips_dialog(_vb, options, xtouch, tool_name)
  vb = _vb
  if scribble_dialog and scribble_dialog.visible then scribble_dialog:show() return end

  local container = vb:horizontal_aligner { mode = 'justify' }
  for i = 1, 8 do
    local s = create_scribble_gui(xtouch.channels[i].screen, options.scribble_gui_brightness, xtouch.screen_bang[i])
    container:add_child(s)
  end

  local content = vb:column { style = 'border', width = options.scribble_gui_width.value, container }
  options.scribble_gui_width:add_notifier(function() content.width = options.scribble_gui_width.value end)

  scribble_dialog = renoise.app():show_custom_dialog(tool_name .. ' | Scribble strips', content)
end