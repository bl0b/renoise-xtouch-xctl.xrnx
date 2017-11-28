_AUTO_RELOAD_DEBUG = function() end

class "ProgramManager"


function ProgramManager:__init()
  local z = function() end
  self.programs = {{name='testing', install=z, uninstall=z}, {name='foo bar baz', install=z, uninstall=z}}
  self._program_number = -1
  
  for k, v in pairs(os.filenames('programs')) do
    local program = dofile('programs/'..v)
    if program.name == 'firmware' then
      self.firmware = program
      self.firmware.install(self)
    else
      self.programs[#self.programs + 1] = program
    end
    print("Have program '"..program.name.."'")
  end
end


function ProgramManager:select_program(program_number)
  if self._program_.number > 0 then
    self.programs[self._program_.number].uninstall(self)
  end
  self._program_.number = program_number
  self.programs[self._program_.number].install(self)
end

