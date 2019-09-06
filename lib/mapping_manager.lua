require 'lib/mappings'

class "MappingManager" (renoise.Document.DocumentNode)

local XTOUCH = 1
local OBSERVABLE = 2


function MappingManager:__init(xtouch)
  self.xtouch = xtouch

  self.bindings = table.create {}
end

-- source is a string always

function MappingManager:has_binding(source)
  return self.bindings[source] ~= nil
end

function MappingManager:get_binding(source)
  return self.bindings[source]
end

-- pseudo double-buffering to handle diffs in a simple manner

function MappingManager:prepare_update()
  self.double_bindings = table.create {}
  for k, v in pairs(self.bindings) do
    self.double_bindings[k] = {old = v}
  end
end

function MappingManager:update_binding(source, mapping)
  self.double_bindings[source] = self.double_bindings[source] or {}
  self.double_bindings[source].new = mapping
end

function MappingManager:finalize_update()
  local added, modified, removed = 0, 0, 0
  for source, v in pairs(self.double_bindings) do
    local old, new = v.old, v.new
    local mappings_differ = old == nil or new == nil
    if not mappings_differ then mappings_differ = not old:is_equal_to(new) end
    if mappings_differ then
      if old ~= nil and new ~= nil then
        -- print("[!!!]", source)
        modified = modified + 1
      elseif old ~= nil then
        -- print("[---]", source)
        removed = removed + 1
      elseif new ~= nil then
        -- print("[+++]", source)
        added = added + 1
      end
      if old ~= nil then old:off(self) end
      if new ~= nil then new:on(self) end
    end
    self.bindings[source] = new
  end
  print("[xtouch] +" .. added .. " !" .. modified .. " -" .. removed)
  self.double_bindings = nil
end