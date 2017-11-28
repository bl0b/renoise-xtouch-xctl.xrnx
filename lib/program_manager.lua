_AUTO_RELOAD_DEBUG = function() end

function XTouch:init_program_manager()
  local z = function() end
  self.programs = {}
  self._program_number = -1
  
  for k, v in pairs(os.filenames('programs')) do
    local program = dofile('programs/'..v)
    if program.name == 'firmware' then
      self.firmware = program
      self.firmware.install(self)
    else
      if self.programs[program.number] then
        error(string.format("Duplicate program number! %d is requested by '%s' and '%s'", program.number, self.programs[program.number].name, program.name))
      end
      self.programs[program.number] = program
    end
    print("Have program '"..program.name.."'")
  end
end


function XTouch:select_program(program_number)
  if self._program_number > 0 then
    self.programs[self._program_number].uninstall(self)
  end
  self._program_number = program_number
  self.programs[self._program_number].install(self)
end

