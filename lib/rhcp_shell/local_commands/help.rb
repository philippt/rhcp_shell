def param_example(param, suffix = "")
  result = ""
  result += "<" if param.is_default_param

  if param.is_default_param then
    result += "#{param.name}#{suffix}"
  else
    result += "#{param.name}"
    result += "=<value#{suffix}>"
  end

  result += ">" if param.is_default_param
  result
end

def add_help_commands(broker)
  command = RHCP::Command.new("help", "displays help about this shell",
    lambda { 
      |req,res|
        
      if (req.has_param_value("command"))
        command_name = req.get_param_value("command")
        puts "Syntax:"
        command_line = "  #{command_name}"
        command = @command_broker.get_command(command_name)

        command.params.sort { |a,b| a.name <=> b.name }.each do |param|
          command_line += " "
          command_line += "[" unless param.mandatory

          command_line += param_example(param)  

          if param.allows_multiple_values then
            command_line += " "
            command_line += param_example(param, "2")
            command_line += " ..."
          end

          command_line += "]" unless param.mandatory
        end
        puts command_line
        puts "Description:"
        puts "  #{command.description}"
        if command.params.size > 0 then
          puts "Parameters:"
          command.params.sort { |a,b| a.name <=> b.name }.each do |param|
            default_value = param.default_value != nil ? " (default: #{param.default_value})" : ''
            param_name = param.name
            if param.is_default_param
              param_name += " *"
            end
            if param.allows_extra_values
              param_name += " ~"
            end
            puts sprintf("  %-20s %s%s\n", param_name, param.description, default_value)
          end
       end
       puts ""
      else
        puts "The following commands are available:"
        @command_broker.get_command_list.values.sort { |a,b| a.name <=> b.name }.each do |command|
          # TODO calculate the maximum command name length dynamically
          # TODO and allow for multiple lines of description (check if it's an array?)
          puts sprintf("  %-40s %s\n", command.name, command.description)
        end
        puts ""
        puts "Type help <command name> for detailed information about a command."
      end          
    }
    ).add_param(RHCP::CommandParam.new("command", "the name of the command to display help for", 
        { 
          :mandatory => false,
          :is_default_param => true,
          :lookup_method => lambda {
            @command_broker.get_command_list.values.map { |c| c.name }
          }
        }
    )
  )
  command.result_hints[:display_type] = "hidden"
  broker.register_command command
end      