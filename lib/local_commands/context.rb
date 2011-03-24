def add_context_commands(broker, context_aware_broker)
  
  command = RHCP::Command.new("show_context", "displays the context currently stored in the local ContextAwareBroker",
    lambda { |req,res| 
      result = []
      @command_broker.context.cookies.each do |k,v|
        result << {
          "key" => k,
          "value" => v
        }
      end
      result
    }
  )
  
  command.result_hints[:display_type] = "table"
  command.result_hints[:overview_columns] = [ "key", "value" ]
  command.result_hints[:column_titles] = [ "key", "value" ]
  command.mark_as_read_only
  command.result_hints[:cache] = false
  
  broker.register_command command
  
end