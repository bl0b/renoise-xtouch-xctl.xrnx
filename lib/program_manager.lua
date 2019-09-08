_AUTO_RELOAD_DEBUG = function() end

require 'lib/schema_manager'

function XTouch:init_program_manager()
  local z = function() end
  self.programs = {}
  self._program_number = -1
  self.schema_manager = nil

  for k, v in pairs(os.filenames('programs')) do
    local program = dofile('programs/' .. v)
    if type(program) == 'function' then
      program = program(self)
      if program ~= nil then
        if self.programs[program.number] then
          error(string.format("Duplicate program number! %d is requested by '%s' and '%s'", program.number, self.programs[program.number].name, program.name))
        end
        self.programs[program.number] = program
        -- print("Have program '"..program.name.."'")
      end
    else
      -- print("Have a program as a table, not a function")
      -- rprint(program)
    end
  end
end

function XTouch:reset()
  if self.schema_manager ~= nil then
    self.schema_manager:unbind_from_song()
    self:close(false)
    self:open()
    self:select_program(self._program_number)
  else
    self:close(false)
    self:open()
  end
end


function XTouch:select_program(program_number)
  -- print('select program #'..program_number)
  if program_number == self._program_number then return end
  local program = self.programs[program_number]
  -- rprint(program)
  if program ~= nil then
    self._program_number = program_number
  else
    return
  end
  if self.schema_manager ~= nil then
    -- print('reuse sm', program)
    -- self.programs[self._program_number].uninstall(self)
    self.schema_manager:execute_compiled_schema_stack({})
    self.schema_manager.set_program(program)
  else
    -- print('new sm', program)
    self.schema_manager = SchemaManager(self, program)
  end
end

