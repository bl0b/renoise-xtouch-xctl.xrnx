_AUTO_RELOAD_DEBUG = function()
  print('Reloaded X-Touch tool.')
  if xtouch == nil then return end
  if xtouch.schema_manager ~= nil then
    xtouch.schema_manager:unbind_from_song()
  end
  xtouch:close()
  xtouch = XTouch(options)
end

require 'lib/gui/tabs'

-- Placeholder for the dialog
local bindings_dialog = nil

local vb = nil


local switcharoo = 'Switch to page '

local active_tab = nil

function create_binding(name, event, descr)
  return vb:row {
    vb:textfield {
      text = event,
      width = 60,
      active = false,
      align = 'center'
    },
    vb:space { width = 2, },
    vb:text {
      text = name,
      width = 90,
      style = 'strong'
    },
    vb:space { width = 2, },
    descr:sub(1, #switcharoo) == switcharoo
    and vb:button {
      text = descr,
      width = 160,
      tooltip = 'Display the bindings of page ' .. descr:sub(#switcharoo + 1),
      notifier = function() active_tab.value = descr:sub(#switcharoo + 1) end
    }
    or vb:text {
      text = descr,
      width = 160,
      style = descr == 'UNDOCUMENTED' and 'disabled' or 'normal'
    }
  }
end

function add_binding(name, event, descr, container)
  container:add_child(create_binding(name, event, descr))
end

function create_group(name)
  return vb:column {
    style = 'group',
    margin = 2,
    spacing = 2,
    vb:row {
      style = 'border',
      margin = 3,
      vb:text {
        style = 'strong',
        text = name,
        width = 210,
        align = 'center'
      }
    }
  }
end



--[[
Ordered table iterator, allow to iterate on the natural order of the keys of a
table.

Example:
]]

function __genOrderedIndex( t )
  local orderedIndex = {}
  for key in pairs(t) do
      table.insert( orderedIndex, key )
  end
  table.sort( orderedIndex )
  return orderedIndex
end

function orderedNext(t, state)
  -- Equivalent of the next function, but returns the keys in the alphabetic
  -- order. We use a temporary ordered key table that is stored in the
  -- table being iterated.

  local key = nil
  if state == nil then
      -- the first time, generate the index
      t.__orderedIndex = __genOrderedIndex( t )
      key = t.__orderedIndex[1]
  else
      -- fetch the next value
      for i = 1,table.getn(t.__orderedIndex) do
          if t.__orderedIndex[i] == state then
              key = t.__orderedIndex[i+1]
          end
      end
  end

  if key then
      return key, t[key]
  end

  -- no more value to return, cleanup
  t.__orderedIndex = nil
  return
end

function orderedPairs(t)
  -- Equivalent of the pairs() function on tables. Allows to iterate
  -- in order
  return orderedNext, t, nil
end


local group_column = {
  ['(ungrouped)'] = 1,
  ['FUNCTION'] = 1,
  ['BANK'] = 1,
  ['CHANNEL'] = 1,
  ['TRANSPORT'] = 1,
  ['ENCODER ASSIGN'] = 1,

  ['TRACK'] = 2,
  ['MAIN TRACK'] = 2,

  ['MODIFY'] = 3,
  ['UTILITY'] = 3,
  ['AUTOMATION'] = 3,
  ['FUNCTION'] = 3,
}


function group_column_index(group_name)
  for prefix, ci in pairs(group_column) do
    if group_name:sub(1, #prefix) == prefix then
      return ci
    end
  end
  print('GROUP HAS NO COLUMN', group_name)
end


function show_bindings_dialog(_vb, xtouch, tool_name, program_number)
    vb = _vb
  -- This block makes sure a non-modal dialog is shown once.
  -- If the dialog is already opened, it will be focused.
  if bindings_dialog and bindings_dialog.visible then
    bindings_dialog:show()
    return
  end

  local program = xtouch.programs[program_number]

  local pages = xtouch.schema_manager:get_descriptions(program)
  local page_count = 0
  local tabs = table.create {}
  for name, page in orderedPairs(pages) do
    page_count = page_count + 1
    local make_col = function()
      return vb:column {
        -- spacing = 5,
        -- width = 420,
        spacing = 5,
        margin = 5,
      }
    end

    local cols = {make_col(), make_col(), make_col()}
    local row = vb:column {
      style = 'panel',
      spacing = 5,
      margin = 0,

      vb:multiline_text {
        style = 'border',
        text = page.description,
        width = 974
      },

      vb:row {margin = 0, cols[1], cols[2], cols[3]}
    }

    local groups = {}

    local add_to_group = function(group, binding)
      if groups[group] == nil then
        groups[group] = create_group(group)
      end
      groups[group]:add_child(binding)
    end

    for k, v in orderedPairs(page.bindings) do
      if v.leaf then
        for i = 1, #v do
          add_to_group('(ungrouped)', create_binding(k, v[i].event, v[i].descr))
        end
      else
        for l, u in orderedPairs(v) do
          for z = 1, #u do
            add_to_group(k, create_binding(l, u[z].event, u[z].descr))
          end
        end
      end
    end

    for group_name, group in orderedPairs(groups) do
      local ci = group_column_index(group_name)
      if ci ~= nil then cols[ci]:add_child(group) end
    end
    tabs[name] = row
  end

  local tabs_gui = Tabs(vb, tabs)
  active_tab = tabs_gui.active_tab
  active_tab.value = program.startup_page
  tabs_gui.view.width = 999
  local content = vb:column {
    width = tabs_gui.view.width,
    -- spacing = 10,
    -- margin = 10,
    -- vb:row {
    --   spacing = 0,
    --   margin = 10,
    --   width = '100%',
    --   style = 'group',
      vb:horizontal_aligner {
        mode = 'center',
        width = '100%',
        margin = 5,
        vb:row {
          vb:text {
            width = 20,
            text = 'Program',
            style = 'normal'
          },
          vb:text {
            width = 20,
            text = program.name,
            style = 'strong'
          },
          vb:text {
            width = 20,
            text = 'has',
            style = 'normal'
          },
          vb:text {
            width = 2,
            text = '' .. page_count,
            style = 'strong'
          },
          vb:text {
            width = 20,
            text = 'pages. Start page is',
            style = 'normal'
          },
          vb:text {
            width = 20,
            text = program.startup_page,
            style = 'strong'
          },
        }
      },
    -- },
    tabs_gui.view
  }

  bindings_dialog = renoise.app():show_custom_dialog(tool_name .. ' | Bindings for program «' .. xtouch.schema_manager.prog.name .. '»', content)
end

