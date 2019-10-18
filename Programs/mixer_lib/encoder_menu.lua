function encoder_menu(spec)
  local menu = {
    _current_entries = {},
    _current_name = {},
    _current_title = {},
    _current_index = {},
    _depth = renoise.Document.ObservableNumber(0),
    index = renoise.Document.ObservableNumber(0),
    entries = spec.entries,
    title = spec.title,
    name = spec.name,
    state = {},
  }

  menu.push = function(title, name, entries)
    menu._current_entries[1 + #menu._current_entries] = entries
    menu._current_name[1 + #menu._current_name] = name
    menu._current_title[1 + #menu._current_title] = title
    menu._current_index[1 + #menu._current_index] = menu.index.value
    print('menu push', title, name, entries and #entries or nil, menu.depth())
    if menu.index.value == 1 then
      menu.index.value = 0
    end
    menu.index.value = 1
    menu._depth.value = menu._depth.value + 1
  end

  menu.pop = function()
    menu._current_entries[#menu._current_entries] = nil
    menu._current_name[#menu._current_name] = nil
    menu._current_title[#menu._current_title] = nil
    menu._current_index[#menu._current_index] = nil
    if menu.index.value == menu._current_index[#menu._current_index] then
      menu.index.value = 0
    end
    menu.index.value = menu._current_index[#menu._current_index]
    menu._current_index[#menu._current_index] = nil
    menu._depth.value = 0
  end

  menu.pop_all = function()
    menu._current_entries = {}
    menu._current_name = {}
    menu._current_title = {}
    menu._current_index = {}
    menu.index.value = 0
    menu._depth.value = 0
    menu.state = {}
  end

  menu.depth = function() return menu._depth.value end

  menu.current_name = function() return menu._current_name[#menu._current_name] end
  menu.current_title = function() return menu._current_title[#menu._current_title] end
  menu.current_entries = function() return menu._current_entries[#menu._current_entries] end
  menu.current_entry = function() local e = menu.current_entries() return e and e[menu.index.value] end
 
  menu.move = function(delta)
    if menu.depth() == 0 or menu.current_entries() == nil then return end
    menu.index.value = math.min(#menu.current_entries(), math.max(1, menu.index.value + delta))
    print('menu.move', menu.index.value)
  end

  menu.enter = function(cursor, state)
    -- print(cursor, state, 'menu enter', menu.depth())
    print('menu.enter')
    if menu.depth() == 0 then
      menu.push(menu.title, menu.name, menu.entries(cursor, state, menu))
      return
    end
    -- print('menu', 'index', menu.index.value, 'entries', menu.current_entries())
    -- print('menu', '#', #menu.current_entries())
    local entry = menu.current_entry()
    menu.state[string.format('%s_index', menu.current_name())] = menu.index.value
    menu.state[string.format('%s_value', menu.current_name())] = entry.value or entry.label
    print("DEBUG MENU POP ALL")
    rprint(menu)
    if entry.callback then
      entry.callback(cursor, state, menu)
    end
    if entry.sub_menu then
      local m = entry.sub_menu
      if m.entries then menu.push(m.title, m.name, m.entries(cursor, state, menu)) end
    elseif menu.pop_all then
      menu.pop_all()
    end
  end

  menu.exit = function(channel)
    if menu.depth() == 0 then return end
    menu.pop()
    print('menu.exit', menu.depth())
  end

  menu.scribble = function(cursor, state)
    if menu.depth() == 0 then
      return { id = 'menu', channel = cursor.channel, ttl = 0 }
    end
    local e = menu.current_entry()
    if e == nil then
      return { id = 'menu', channel = cursor.channel, ttl = 0 }
    end
    return {
      id = 'menu',
      channel = cursor.channel,
      line1 = string.format('%-7s', string.format('%s:', menu.current_title())),
      line2 = string.format('%7s', strip_vowels(e and e.label or '')),
      inverse = true,
      ttl = 5.0,
    }
  end

  return menu
end

function with_menu_mappings(xtouch, page)
  local frame_name = page.frame.name
  local src = function(source, event)
    if event ~= nil then
      return string.format('cursor.%s.menu ~= nil and %s or nil,%s', frame_name, source, event)
    else
      return string.format('cursor.%s.menu ~= nil and %s or nil', frame_name, source)
    end
  end
  local t = page.frame.assign
  t[1 + #t] = { obs = src(string.format('cursor.%s.menu.index', frame_name)), scribble = function(c, s) return c[frame_name].menu.scribble(c, s) end, }
  t[1 + #t] = { obs = src(string.format('cursor.%s.menu._depth', frame_name)), scribble = function(c, s) return c[frame_name].menu.scribble(c, s) end, }
  t[1 + #t] = { xtouch = src('xtouch.channels[cursor.channel].encoder', 'click'), callback = function(c, s) c[frame_name].menu.enter(c, s) end, }
  t[1 + #t] = { xtouch = src('xtouch.channels[cursor.channel].encoder', 'long_press'), callback = function(c, s) c[frame_name].menu.exit(c.channel) end, }
  t[1 + #t] = { xtouch = src('xtouch.channels[cursor.channel].encoder', 'delta'), callback = function(cursor, state) cursor[frame_name].menu.move(xtouch.channels[cursor.channel].encoder.delta.value) end, }
  return page
end