



return {
  name = 'default',
  number = 99,
  install = function(xtouch, state)
    print('installed default')
  end,
  uninstall = function(xtouch, state)
    print('uninstalled default')
  end
}
