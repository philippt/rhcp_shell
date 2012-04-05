# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
 

$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'rhcp_shell_backend'

require 'rubygems'
require 'rhcp'
require 'logger'

require 'setup_test_registry'

class RhcpShellBackendTest < Test::Unit::TestCase
  
  # Backend that "remembers" everything it ever printed to the user
  class BackendMock < RHCPShellBackend

      def initialize(broker, on_receive)
        super(broker)
        @on_receive = on_receive
      end
    
      def process_input(line)
        $stdout.puts "[user] #{line}"
        super(line)
      end
      
      def puts(what)
        $stdout.puts "[shell] #{what}"
        @on_receive.call(what)
      end      
      
      def set_prompt(new_prompt)
        $stdout.puts "[shell: switching prompt to '#{new_prompt}']"
        super(new_prompt)
      end

      def complete(word = "")
        result = super(word)
        proposal_list = result.map { |p| "'#{p}'" }.join(" ")
        $stdout.puts "[completion proposals : #{proposal_list}]"
        result
      end
      
  end  
  
  def setup
    # set up a local broker that we'll use for testing
    # TODO do something about this - it shouldn't be necessary to instantiate the logger beforehand
    $logger = Logger.new($stdout)
    @log = Array.new()
    @backend = BackendMock.new($broker, self.method(:add_to_log))
  end
  
  def add_to_log(new_line)
    #puts "adding to log (old size : #{@log.size}): *****#{new_line}*****"
    @log << new_line
    # TODO CAREFUL: if you un-comment the following line, @log will get screwed up
    #puts "log now : >>#{@log.join("\n")}<<"
  end
  
  def assert_received(expected)
    @log_slice = expected.length < @log.length ?
      @log.slice(- expected.length, expected.length) :
      @log
    assert_equal(expected, @log_slice)
    # clean the log so that assert_no_error works
    #@log.clear
  end

  def assert_no_error
    assert_equal 0, @log.select { |line| 
      /error/i =~ line || /exception/i =~ line || /failed/i =~ line
    }.size
  end
  
  def assert_log_contains(stuff)
    is_ok = @log.grep(/#{stuff}/).size > 0
    puts "checking log for #{stuff}"
    assert is_ok, "log should contain '#{stuff}', but it doesn't : >>#{@log.join("\n")}<<"
  end
  
  def assert_prompt(expected)    
    if (expected == '')
      assert_equal "$ ", @backend.prompt
    else
      assert_equal "#{expected} $ ", @backend.prompt
    end
  end
  
  def test_banner
    @backend.banner = "This is a test backend"
    @backend.show_banner
    assert_received [ "This is a test backend" ]
  end
  
  def test_simple_execute  
    @backend.process_input "test"
    assert_received [ "executed 'test' successfully : 42" ]
  end    
  
  def test_invalid_command
    @backend.process_input "does not exist"
    assert_received [ "no such command : does" ]
  end
  
  def test_missing_mandatory_param
    @backend.process_input "reverse"
    assert_prompt 'reverse.input'
    @backend.process_input "zaphod"
    assert_received [ "executed 'reverse' successfully : dohpaz" ]
  end
  
  def test_completion
    @backend.process_input "reverse"
    assert_prompt 'reverse.input'
    assert_equal [ "zaphod", "beeblebrox" ], @backend.complete
  end
  
  def test_command_completion
    commands = $broker.get_command_list.values.map { |command| command.name }
    # we should have all remote commands plus "help" and "exit"
    commands << "help"
    commands << "exit"
    commands << "detail"
    commands << "show_context"
    commands << "set_prompt"
    assert_equal commands.sort, @backend.complete.sort
    assert_no_error
  end
  
  def test_params_on_command_line
    @backend.process_input "reverse input=zaphod"
    assert_received [ "executed 'reverse' successfully : dohpaz" ]
  end
  
  def test_invalid_param_value
    @backend.process_input "reverse input=bla"
    assert_received [ "ignoring parameter value 'bla' for param 'input' : invalid value 'bla' for parameter 'input'" ]
  end
  
  def test_multi_params
    @backend.process_input "cook"
    assert_prompt 'cook.ingredient'
    @backend.process_input "mascarpone"
    @backend.process_input "chocolate"
    @backend.process_input ""
    assert_no_error    
    assert_received [ "executed 'cook' successfully : mascarpone chocolate" ]
  end
  
  # if the user is in command mode, he should be able to exit to command mode
  # by pressing ctrl+c
  def test_abort_param_mode
    @backend.process_input "cook"
    assert_prompt 'cook.ingredient'
    @backend.process_ctrl_c
    assert_prompt ''
  end
  
  def test_failing_command
    @backend.process_input "perpetuum_mobile"
    assert_received [ "could not execute 'perpetuum_mobile' : don't know how to do this" ]
  end

  def test_preprocess_without_lookup_values
    @backend.process_input "test thoroughly=yes"
    assert_no_error
  end

# TODO reactivate wildcards
#  def test_wildcard_support
#    @backend.process_input "cook ingredient=m*"
#    assert_received [ "executed 'cook' successfully : mascarpone marzipan" ]
#  end
#
#  def test_wildcard_ranges
#    @backend.process_input "echo input=string01..05"
#    assert_received [ "executed 'echo' successfully : string01 string02 string03 string04 string05" ]
#
#    @backend.process_input "echo input=string17..20"
#    assert_received [ "executed 'echo' successfully : string17 string18 string19 string20" ]
#  end
  
  def test_help
    @backend.process_input "help"
    assert_log_contains "The following commands are available"
    $broker.get_command_list.values.each do |command|
      assert_log_contains command.name
    end
  end
    
  def test_help_command
    @log.clear
    @backend.process_input "help cook"
    puts "LOG >>#{@log}<<"
    assert_log_contains "Syntax:"
    assert_log_contains "cook ingredient=<value> ingredient=<value2> ..."
  end
  
  def test_help_with_default_param
    @backend.process_input "help help"
    puts "LOG >>#{@log}<<"
    assert_log_contains "Syntax:"
    assert_log_contains "help [<command>]"
  end
  
  def test_default_param
    @backend.process_input "reverse zaphod"
    assert_received [ "executed 'reverse' successfully : dohpaz" ]
  end
  
  # unnamed params should be ignored if no default params are specified
  def test_unnamed_param_without_default_param
    @backend.process_input "echo bla"
    assert_received [ "executed 'echo' successfully : hello world" ]
  end
  
  def test_complete_without_lookup_values
    @backend.process_input "length"
    assert_prompt "length.input"
    assert_equal [], @backend.complete
  end
  
  def test_table
    # TODO write a separate test for this stuff
    p $broker.get_command("build_a_table")
    @backend.process_input "build_a_table"
#   puts "===================\n#{@log}\n=====================\n"
    assert_received [
      "---------------------------------------\n" +
      "| # | __idx | first_name | last_name  |\n" +
      "---------------------------------------\n" +
      "|   | 1     | Arthur     | Dent       |\n" +
      "|   | 2     | Prostetnik | Yoltz (?)  |\n" +
      "|   | 3     | Zaphod     | Beeblebrox |\n" +
      "---------------------------------------\n"
    ]
  end
  
  def test_empty_table
    @backend.process_input "build_a_table empty=true"
    assert_received [
      "--------------------------------------\n" +
      "| # | __idx | first_name | last_name |\n" +
      "--------------------------------------\n" +
      "--------------------------------------\n"
    ]
    puts "===================\n#{@log}\n=====================\n"
  end

  # TODO test behaviour after an internal error occurred in the shell (e.g. some problem while formatting the result)
#  E, [2009-09-17T01:21:53.399309 #9118] ERROR -- : comparison of Fixnum with nil failed (ArgumentError)
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/rhcp_shell_backend.rb:335:in `>'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/rhcp_shell_backend.rb:335:in `execute_command'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/rhcp_shell_backend.rb:334:in `each'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/rhcp_shell_backend.rb:334:in `execute_command'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/rhcp_shell_backend.rb:183:in `execute_command_if_possible'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/rhcp_shell_backend.rb:475:in `process_input'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/base_shell.rb:93:in `run'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/base_shell.rb:84:in `initialize'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/base_shell.rb:84:in `new'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/base_shell.rb:84:in `run'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/base_shell.rb:83:in `loop'
#  /var/lib/gems/1.8/gems/rhcp_shell-0.0.7/lib/base_shell.rb:83:in `run'
#  ./virtualop_rhcp.rb:131:in `setup_local_shell'
#  ./virtualop_rhcp.rb:168
#  exception raised: comparison of Fixnum with nil failed

  # say_hello should be workable with normal parameters
  def test_context_handling_normal_parameter
    @backend.command_broker.context.cookies.clear
    @backend.process_input "say_hello the_host=zaphod"
    assert_received [ "executed 'say_hello' successfully : hello from zaphod" ]
  end

  def test_command_completion_with_context
    # we should not see let_explode_host, but both say_hello and switch_host
    assert @backend.complete.select { |command| command == "say_hello" }.size() > 0
    assert @backend.complete.select { |command| command == "switch_host" }.size() > 0
    assert @backend.complete.select { |command| command == "let_explode_host" }.size() == 0

    # test if this changes with context
    @backend.process_input "switch_host new_host=serenity"
    assert @backend.complete.select { |command| command == "let_explode_host" }.size() > 0
  end

  def test_context_handling
    # context values should be usable by commands
    @backend.process_input "switch_host new_host=serenity"
    #@backend.context['host'] = 'serenity'
    @backend.process_input "say_hello"
    assert_received [ "executed 'say_hello' successfully : hello from serenity" ]
  end

  def test_command_setting_context
    @backend.process_input "switch_host new_host=moon"
    @backend.process_input "say_hello"
    assert_received [ "executed 'switch_host' successfully : hostmoon",
                      "executed 'say_hello' successfully : hello from moon" ]
  end

  
end