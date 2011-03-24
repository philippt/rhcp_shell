def add_set_prompt_command(broker, shell_backend)

  command = RHCP::Command.new("set_prompt", "changes the current prompt",
    lambda { |req,res| 
      res.set_context("prompt" => req.get_param_value("new_prompt"))      
    }
    ).add_param(RHCP::CommandParam.new("new_prompt", "the new prompt that should be used from now on",
      {
        :is_default_param => true,
        :mandatory => true            
      }
    )
  )
  command.result_hints[:display_type] = "hidden"
  broker.register_command command
  
end  