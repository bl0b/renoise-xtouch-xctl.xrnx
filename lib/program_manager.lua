_AUTO_RELOAD_DEBUG = function() end

require 'lib/schema_manager'

function XTouch:init_program_manager()
  local z = function() end
  self.programs = {}
  self._program_number = -1
  self.schema_manager = SchemaManager(self)
  
  for k, v in pairs(os.filenames('programs')) do
    local program = dofile('programs/'..v)
    if type(program) == 'function' then
      local schema = program(self)
      if schema ~= nil then
        if self.programs[schema.number] then
          error(string.format("Duplicate program number! %d is requested by '%s' and '%s'", schema.number, self.programs[schema.number].name, schema.name))
        end
        self.programs[schema.number] = schema
        print("Have program '"..schema.name.."'")
      end
    else
      print("Have a program as a table, not a function")
      rprint(program)
    end
  end
end


function XTouch:select_program(program_number)
  print('select program #'..program_number)
  if self._program_number > 0 then
    -- self.programs[self._program_number].uninstall(self)
    self.schema_manager:clear_assigns()
    self.schema_manager = SchemaManager(self)
  end
  self._program_number = program_number
  -- self.programs[self._program_number].install(self)
  self.schema_manager:push(self.programs[self._program_number])
end

