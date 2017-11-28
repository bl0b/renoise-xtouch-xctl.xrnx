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
function match_color(r, g, b)
  local xtcol = {{255, 0, 0}, {0, 255, 0}, {255, 255, 0}, {0, 0, 255}, {255, 0, 255}, {0, 255, 255}, {255, 255, 255}}
  local best = 7
  local bestproj = 1000000
  if r == 0 and g == 0 and b == 0 then
    return 0
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
  return best
end





-- dump a midi message in the terminal
-- (prefix, message) -> nil
function print_msg(s, msg)
  for i = 1, #msg do
    --print("msg byte", i, msg[i])
    --rprint(msg[i])
    --oprint(msg[i])
    s = s .. ' ' .. string.format('%02x', msg[i] or {state = false, led = 0})
  end
  print(s)
end



-- copy the contents of a scribble strip line into a SYSEX at the right place. see usage in send_screen.
-- (line, sysex, line number) -> nil
function str2arr(str, msg, line)
  local ret = {}
  local ofs = 7 * line
  for i = 1, #str do
    msg[ofs + i] = string.byte(str:sub(i,i))
    --table.insert(ret, str.byte(i))
  end
  for i = #str + 1, 7 do
    --table.insert(ret, {state = false, led = 0})
    msg[ofs + i] = 0
  end
end


-- send message for screens
-- (channel) -> (outfunc, screen table) -> nil
function send_screen(channel)
  return function (out, screen)
    local flag = screen.inverse.value and 0x40 or 0
    local msg = {0xf0, 0, 0, 0x66, 0x58, 0x20 + channel, flag + match_color(screen.color[1].value, screen.color[2].value, screen.color[3].value), 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0xf7}
    str2arr(screen.line1.value, msg, 1)
    str2arr(screen.line2.value, msg, 2)
    out(msg)
  end
end



-- describe how to send what in an X-Touch track
-- (channel) -> [table]


function find_element(source, path)
  local cur = source
  local last = source
  local name = path
  for name in string.gmatch(path, '[%w_]+') do
    --print(name, cur ~= nil)
    last = cur
    if cur[name] == nil then
      cur[name] = {}
    end
    cur = cur[name]
  end
  return cur, name, last
end


