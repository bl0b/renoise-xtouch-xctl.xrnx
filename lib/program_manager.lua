_AUTO_RELOAD_DEBUG = function() end

class "ProgramManager"



function state_change(observable)
end

function ProgramManager:__init()
  print('filenames')
  rprint(os.filenames('.'))
  print('dirnames')
  rprint(os.dirnames('.'))
  
  self.programs = {}
  
  for k, v in pairs(os.filenames('programs')) do
    local program = dofile('programs/'..v)
    print("Have program '"..program.name.."'")
    self.programs[#self.programs + 1] = program
  end
  
  self.button_states = {}
  self.button_hooks = {}
  self.fader_hooks = {}
  self.encoder_hooks = {}
end

