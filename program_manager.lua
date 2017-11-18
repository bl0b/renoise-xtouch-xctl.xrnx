_AUTO_RELOAD_DEBUG = function() end

class "ProgramManager"


function ProgramManager:__init()
  print('filenames')
  rprint(os.filenames('.'))
  print('dirnames')
  rprint(os.dirnames('.'))
  
  self.programs = {}
  
  for k, v in pairs(os.filenames('programs')) do
    name, program = dofile('programs/'..v)
    print("Have program '"..name.."'")
    self.programs[name] = program
  end
end
