

function condense_sequence(tab)
  local buckets = {{1, 1}}
  for i = 2, #tab do
    if tab[i] == tab[buckets[#buckets][2]] + 1 then
      buckets[#buckets][2] = i
    else
      buckets[#buckets + 1] = {i, i}
    end
  end
  for i = 1, #buckets do
    local b = buckets[i]
    if b[1] == b[2] then
      buckets[i] = '#' .. tab[b[1]]
    else
      buckets[i] = '#' .. tab[b[1]] .. '-#' .. tab[b[2]]
    end
  end
  return table.concat(buckets, ', ')
end


function description_key(source, frame_channels)
  source = source:gsub('.* and ', '')
  source = source:gsub('xtouch.', '')
  source = source:gsub(' or [^,]+', '')
  if frame_channels then
    source = source:gsub('cursor[.]channel', '')  -- only happens within frame assigns
    source = source:gsub('channels[[]].', 'Tracks ' .. frame_channels .. '/')  -- only happens within frame assigns
  end
  source = source:gsub('channels[[](%d)[]].', 'Track #%1/')  -- only happens within frame assigns
  source = source:gsub('channels.main.', 'Main Track/')  -- only happens within frame assigns
  source = source:gsub('^left', 'Cursor/◀')
  source = source:gsub('^right', 'Cursor/▶')
  source = source:gsub('^down', 'Cursor/▼')
  source = source:gsub('^up', 'Cursor/▲')
  source = source:gsub('^foot', 'Foot Controls/FOOT')
  source = source:gsub('^expression', 'Foot Controls/expression')
  source = source:gsub('^(.+)[.]left', '%1/◀')
  source = source:gsub('^(.+)[.]right', '%1/▶')
  source = source:gsub(' *[-][-].+', '')
  source = source:gsub('_', ' ')
  source = source:upper()
  local split_event = source:gmatch('[^,]+')
  local path, event = split_event(), split_event()
  local split_path = path:gmatch('[^./]+')
  local deep_path = table.create {}
  for i in split_path do
    deep_path[1 + #deep_path] = '' .. i
  end
  return deep_path, event
end


function create_path(dest_table, deep_path, i, event, descr)
  if #deep_path == i then
    if dest_table[deep_path[i]] == nil then
      dest_table[deep_path[i]] = table.create { leaf = true }
    end
    local t = dest_table[deep_path[i]]
    t[#t + 1] = {event=event, descr=descr}
    return
  end
  if dest_table[deep_path[i]] == nil then
    dest_table[deep_path[i]] = table.create {}
  end
  create_path(dest_table[deep_path[i]], deep_path, i + 1, event, descr)
end


function SchemaManager:analyze_binding(cursor, binding, dest_table, frame_channels)
  if binding.no_description then return end

  local xt, descr = binding.xtouch or binding.fader, binding.description

  if type(xt) == 'function' then
    xt = xt(cursor, self.state)
  end
  if xt == nil and binding.vu then
    local vu = binding.vu
    if type(vu) == 'function' then
      vu = vu(cursor, self.state)
    end
    xt = 'channels[' .. vu .. '].VU Meter'
  end
  if xt ~= nil and descr == nil then
    if binding.page ~= nil then
      descr = "Switch to page " .. binding.page
    elseif binding.cursor_step ~= nil then
      if binding.cursor_step < 0 then
        descr = "Move frame left by " .. (-binding.cursor_step)
      else
        descr = "Move frame right by " .. binding.cursor_step
      end
    else
      descr = 'UNDOCUMENTED'
    end
  end
  -- rprint(binding)
  -- print(xt, '::', descr)
  if xt ~= nil and descr ~= nil then
    -- dest_table[reformat(xt)] = descr
    local deep_path, event = description_key(xt, frame_channels)
    create_path(dest_table, deep_path, 1, event, descr)
  end
end


function SchemaManager:get_descriptions(program)
  local ret = table.create {}
  local schemas = table.create {}
  if program == nil then program = self.prog end

  for id, schema_fun in pairs(program.schemas) do
    schemas[id] = schema_fun(self.xtouch, program.state)
  end

  local cursor = table.create {channel=''}
  for id, schema in pairs(schemas) do
    if schema.frame ~= nil then
      -- print('*', schema.frame.name)
      cursor[schema.frame.name] = '##'
    end
  end

  for page_name, page in orderedPairs(program.pages) do
    local dt = table.create {
      name = page_name,
      bindings = table.create {},
      description = page.description
    }

    for i = 1, #page.schemas do
      local schema = program.schemas[page.schemas[i]](self.xtouch, program.state)
      local frame_channels = schema.frame ~= nil and condense_sequence(schema.frame.channels) or nil
      if schema.assign ~= nil then
        for _, binding in ipairs(schema.assign) do
          self:analyze_binding(cursor, binding, dt.bindings, frame_channels)
        end
      end
      if schema.frame ~= nil then
        -- print('frame', schema.frame.name)
        for _, binding in ipairs(schema.frame.assign) do
          self:analyze_binding(cursor, binding, dt.bindings, frame_channels)
        end
      end
    end
    ret[page_name] = dt
  end

  return ret
end

