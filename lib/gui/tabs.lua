class "Tabs" (renoise.Document.DocumentNode)


function Tabs:__init(vb, contents)
  renoise.Document.DocumentNode.__init(self)
  self.vb = vb
  self.active_tab = renoise.Document.ObservableString('')
  self.active_tab_index = renoise.Document.ObservableNumber(0)
  self.active_tab:add_notifier(function() self.active_tab_index.value = table.find(self.headers.items, self.active_tab.value) end)
  self.headers = vb:switch {width = '100%', bind = self.active_tab_index, notifier = function() self.active_tab.value = self.headers.items[self.headers.value] end}
  self.bodies = vb:column {width = '100%', style = 'group'}
  self.view = vb:column { margin = 5, width = '100%', self.headers, self.bodies }
  for k, v in pairs(contents) do
    self:add_tab(k, v)
  end
end

function Tabs:add_tab(title, content)
  local tab = table.copy(self.headers.items)
  if     tab[1] == '1' then tab[1] = title
  elseif tab[2] == '2' then tab[2] = title
  else   tab[#tab + 1] = title
  end
  self.headers.items = tab
  -- self.headers.items[title] = title
  -- self.headers:add_child(self.vb:button { text = title, notifier = function() self.active_tab.value = title end})
  content.visible = title == self.active_tab.value
  -- content.width = '100%'
  self.bodies:add_child(content)
  self.active_tab:add_notifier(function() content.visible = title == self.active_tab.value end)
  if self.active_tab.value == '' then self.active_tab.value = title end
end

function Tabs:set_active_tab(tab) self.active_tab.value = tab end