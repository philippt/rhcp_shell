require 'rubygems'
require 'rhcp'


broker = RHCP::Broker.new()
broker.clear()
broker.register_command RHCP::Command.new("test", "just a test command", 
  lambda { |req,res| 
    42 
  }
  ).add_param(RHCP::CommandParam.new("thoroughly", "an optional param", 
      { 
        :mandatory => false
      }
  )
)
broker.register_command RHCP::Command.new("echo", "prints a string", 
  lambda { |req,res| 
    strings = req.has_param_value("input") ? req.get_param_value("input") : [ "hello world" ]
    result = Array.new
    strings.each do |s|
      puts s
      result << s
    end
    result.join(" ")
  }
  ).add_param(RHCP::CommandParam.new("input", "an optional param", 
      { 
        :mandatory => false,
        :allows_multiple_values => true,
        :lookup_method => lambda {
          values = Array.new()
          1.upto(20) do |i|
            values << "string#{sprintf("%02d", i)}"
          end
          values
        }
      }
  )
)
broker.register_command RHCP::Command.new("reverse", "reversing input strings", 
  lambda { |req,res| 
    req.get_param_value("input").reverse 
  }
  ).add_param(RHCP::CommandParam.new("input", "the string to reverse", 
      { 
        :lookup_method => lambda { [ "zaphod", "beeblebrox" ] },
        :mandatory => true,
        :is_default_param => true
      }
  )
)
broker.register_command RHCP::Command.new("cook", "cook something nice out of some ingredients", 
  lambda { |req,res| 
    ingredients = req.get_param_value("ingredient").join(" ")
    puts "cooking something with #{ingredients}"
    ingredients
  }
  ).add_param(RHCP::CommandParam.new("ingredient", "something to cook with", 
      { 
        :lookup_method => lambda { [ "mascarpone", "chocolate", "eggs", "butter", "marzipan" ] },
        :allows_multiple_values => true,
        :mandatory => true
      }
  )
)
broker.register_command RHCP::Command.new("perpetuum_mobile", "this command will fail", 
  lambda { |req,res| 
    raise "don't know how to do this"
  }
)
broker.register_command RHCP::Command.new("length", "returns the length of a string", 
  lambda { |req,res| 
    req.get_param_value("input").length
  }
  ).add_param(RHCP::CommandParam.new("input", "the string to reverse", 
      { 
        :mandatory => true,
        :is_default_param => true
      }
  )
)

command = RHCP::Command.new("list_stuff", "this command lists stuff", 
  lambda { |req,res|
    [ "peace", "aquaeduct", "education" ]
  }
)
command.mark_as_read_only()
command.result_hints[:display_type] = "list"
broker.register_command command

command2 = RHCP::Command.new("build_a_table", "this command returns tabular data", 
  lambda { |req,res|
    req.has_param_value("empty") ? [] :
    [
      { "first_name" => "Zaphod", "last_name" => "Beeblebrox", "heads" => 2, "character" => "dangerous" },
      { "first_name" => "Arthur", "last_name" => "Dent", "heads" => 1, "character" => "harmless (mostly)" },
      { "first_name" => "Prostetnik", "last_name" => "Yoltz (?)", "heads" => 1, "character" => "ugly" }
    ]
  }
).add_param(RHCP::CommandParam.new("empty", "if this is true, the table will be empty",
      {
        :mandatory => false,
        :is_default_param => true
      }
))
command2.mark_as_read_only()
command2.result_hints[:display_type] = "table"
command2.result_hints[:overview_columns] = [ "first_name", "last_name" ]
broker.register_command command2

p broker.get_command("build_a_table")


switch_host = RHCP::Command.new("switch_host", "modifies the context",
  lambda { |request, response|
    response.set_context({'host' => request.get_param_value('new_host')})
  }
)
switch_host.add_param(RHCP::CommandParam.new("new_host", "the new host name",
    {
      :mandatory => true,
      :is_default_param => true,
    }
))
broker.register_command switch_host

host_command = RHCP::Command.new("say_hello", "uses context",
  lambda { |request, response|
    "hello from " + request.get_param_value('the_host')
  }
)
host_command.add_param(RHCP::CommandParam.new("the_host", "the host name (should be taken from context)",
    {
      :mandatory => true,
      :is_default_param => true,
      :autofill_context_key => 'host'
    }
))
broker.register_command host_command

context_command = RHCP::Command.new("let_explode_host", "available only in host context",
  lambda { |request, response|
    "kaboom."
  }
)
context_command.enabled_through_context_keys = ['host']
broker.register_command context_command

$broker = broker