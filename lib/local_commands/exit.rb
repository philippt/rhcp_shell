def add_exit_command(broker)
  broker.register_command RHCP::Command.new("exit", "closes the shell", 
    lambda { |req,res| 
      puts "Have a nice day"
      #self.process_ctrl_c
      Kernel.exit(0)
    }
  )
end