_AUTO_RELOAD_DEBUG = function() end

require 'lib/schema_manager'

function XTouch:init_program_manager(tool_preferences)
  local z = function() end
  self.programs = {}
  self._program_number = renoise.Document.ObservableNumber(1)
  self._program_number:add_notifier({self, self.__select_program})
  if tool_preferences:property('current_program_number') == nil then
    tool_preferences:add_property('current_program_number', self._program_number)
  end
  self.schema_manager = nil

  for k, v in pairs(os.filenames('programs')) do
    local program = dofile('programs/' .. v)
    if type(program) == 'function' then
      program = program(self)
      if program ~= nil then
        if self.programs[program.number] then
          error(string.format("[xtouch] Duplicate program number! %d is requested by '%s' and '%s'", program.number, self.programs[program.number].name, program.name))
        end
        self.programs[program.number] = program
        -- print("Have program '"..program.name.."'")
        if not tool_preferences.program_config:property(program.name) == nil then
          tool_preferences.program_config:add_property(program.name, program.config)
        end
      end
    else
      -- print("Have a program as a table, not a function")
      -- rprint(program)
    end
  end
end

function XTouch:reset()
  self:close(false)
  local f = function() self.force_reset:bang() self.is_alive:remove_notifier(f) end
  self.is_alive:add_notifier(f)
  self:open()
end


function XTouch:select_program(program_number)
  self._program_number.value = program_number
end


function XTouch:__select_program()
  -- print('[xtouch] select program #'..self._program_number.value)
  -- if program_number == self._program_number.value then return end
  local program = self.programs[self._program_number.value]
  -- rprint(program)
  -- if program ~= nil then
  --   self._program_number.value = program_number
  -- else
  --   return
  -- end
  if self.schema_manager ~= nil then
    -- print('reuse sm', program)
    -- self.programs[self._program_number.value].uninstall(self)
    self.schema_manager:execute_compiled_schema_stack({})
    self.program_config = program.config
    self.schema_manager.set_program(program)
  else
    -- print('new sm', program)
    self.program_config = program.config
    self.schema_manager = SchemaManager(self, program)
  end
end

