class "Tabs"


function Tabs:__init(vb, width)
  self.vb = vb
  self.active_tab = renoise.Document.ObservableString('')
  self.active_tab_index = renoise.Document.ObservableNumber(0)
  self.headers = vb:switch {width = width - 10, bind = self.active_tab_index, notifier = function() self.active_tab.value = self.headers.items[self.headers.value] end}
  self.bodies = vb:column {width = width - 10, style = 'group'}
  self.view = vb:column { margin = 5, width = width, self.headers, self.bodies }
  self.active_tab:add_notifier(function()
    if self.backup_width ~= nil then self.view.width = self.backup_width end
  end)
end

function Tabs:fix_width(w) self.view.width = w self.backup_width = w end

function Tabs:add_tab(title, content)
  local tab = table.copy(self.headers.items)
  if     tab[1] == '1' then tab[1] = title
  elseif tab[2] == '2' then tab[2] = title
  else   tab[#tab + 1] = title
  end
  self.headers.items = tab
  content.visible = false
  self.bodies:add_child(content)
  self.active_tab:add_notifier(function() content.visible = title == self.active_tab.value end)
end

function Tabs:set_active_tab(tab)
  local i = table.find(self.headers.items, tab)
  if i == nil then return end
  self.active_tab_index.value = i
end