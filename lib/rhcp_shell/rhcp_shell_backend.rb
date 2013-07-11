require 'rhcp_shell/shell_backend.rb'

require 'rhcp_shell/local_commands/help'
require 'rhcp_shell/local_commands/detail'
require 'rhcp_shell/local_commands/exit'
require 'rhcp_shell/local_commands/context'
require 'rhcp_shell/local_commands/set_prompt'

require 'rhcp_shell/display_types/table'
require 'rhcp_shell/display_types/hash'

require 'rhcp_shell/util/colorize'

require 'rubygems'
require 'rhcp'
#require 'rhcp/memcached_broker'

# This shell presents RHCP commands to the user and handles all the parameter
# lookup, validation and command completion stuff
#
# It uses a RHCP registry/broker as a data backend and possibly for communication with
# a server.
#
# This shell implementation handles two modes - one for entering/selecting
# a command, another for entering/selecting parameter values.
# If a command and all mandatory parameters are entered/selected, the command is
# executed.
class RHCPShellBackend < ShellBackend

  # TODO refactor this monstrosity

  attr_reader :last_response
  attr_accessor :banner

  attr_reader :command_broker
  attr_accessor :lookup_broker    
  
  def initialize(command_broker, options = {})
    super()

    local_broker = setup_local_broker
    dispatcher = RHCP::DispatchingBroker.new()
    dispatcher.add_broker(command_broker)
    dispatcher.add_broker(local_broker)

    @command_broker = RHCP::Client::ContextAwareBroker.new(dispatcher)
    @lookup_broker = @command_broker    

    @lookup_cache = {}
    
    @current_prompt = nil
    
    @prompt_color_enabled = options.has_key?(:color_prompt) ?
      options[:color_prompt] : false
    
    reset_to_command_mode
  end
  
  def wrap_lookup_broker
    @lookup_broker = RHCP::MemcachedBroker.new(@lookup_broker)
  end
  
  def setup_local_broker    
    broker = RHCP::Broker.new()
    begin
      add_exit_command(broker)
      add_help_commands(broker)
      add_detail_command(broker)
      add_context_commands(broker, @command_broker)
      add_set_prompt_command(broker, self)
    rescue RHCP::RhcpException => ex
      # TODO do we really want to catch this here?
      raise ex unless /duplicate command name/ =~ ex.to_s
    end
    broker
  end
  
  def reset_to_command_mode
    # this shell has two modes that determine the available tab completion proposals
    # command_mode
    #    we're waiting for the user to pick a command that should be executed
    # parameter mode
    #    the command to execute has already been selected, but the user needs to specify additional parameters
    # we'll start in the mode where no command has been selected yet
    @command_selected = nil
    
    # if the user selected a command already, we'll have to collect parameters for this command until
    # we've got all mandatory parameters so that we can execute the command
    @collected_values = {}

    
    # the mandatory params that are still missing (valid in parameter mode only) 
    @missing_params = Array.new    
    
    # the parameter that we're asking for right now
    @current_param = nil
  end
  
  def execute_command_if_possible
    # check if we got all mandatory params now
    mandatory_params = @command_broker.get_mandatory_params(@command_selected.name)
    #mandatory_params = @command_selected.get_mandatory_params()
    @missing_params = mandatory_params.select { |p| ! @collected_values.include? p.name }
    
    if (@missing_params.size > 0) then
      $logger.debug "got #{@missing_params.size} missing params : #{@missing_params.map{|param| param.name}}"    
      @current_param = @missing_params[0]
    else 
      execute_command
    end
  end
  
  
  def pre_process_param_value(new_value)
    $logger.debug "resolving wildcards for param '#{@current_param.name}'"
      
    # we can only resolve wildcards if we have lookup values
    if (@current_param.has_lookup_values)
      # TODO this is only necessary if we've got multiple values, right?
      # TODO maybe we want to check if 'new_value' holds suspicious characters that necessitate wildcard resolution?    
      # TODO is the range handling possible only with lookup values?
      # convert "*" into regexp notation ".*"
      regex_str = new_value.gsub(/\*/, '.*')

      # handle ranges (42..45)
      result = /(.+?)(\d+)(\.{2})(\d+)(.*)/.match(regex_str)
      ranged_regex = nil
      if result then
        $logger.debug "captures : #{result.captures.map { |v| " #{v} "}}"
        result.captures[1].upto(result.captures[3]) do |loop|
          regex_for_this_number = "#{result.captures[0]}#{loop}#{result.captures[4]}"
          $logger.debug "regex for #{loop} : #{regex_for_this_number}"
          if ranged_regex == nil then
            ranged_regex = Regexp.new(regex_for_this_number)
          else
            ranged_regex = Regexp.union(ranged_regex, Regexp.new(regex_for_this_number))
          end
        end
      else
        ranged_regex = Regexp.new('^' + regex_str + '$')
      end

      $logger.debug "wildcard regexp : #{ranged_regex}"

      re = ranged_regex

      # get lookup values, filter and return them
      request = RHCP::Request.new(@command_selected, @collected_values)
      lookup_values = @command_broker.get_lookup_values(request, @current_param.name )
      #lookup_values = @current_param.get_lookup_values()
      lookup_values.select { |lookup_value| re.match(lookup_value) }
    else
      [ new_value ]
    end
  end
  
  # checks param values for validity and adds them to our value collection
  # expands wildcard parameters if appropriate
  # returns the values that have been added (might be more than 'new_value' when wildcards are used)
  def add_parameter_value(new_value)
    # pre-process the value if necessary
    # TODO reactivate wildcard checking (too expensive right now and we aren't using it)
    #processed_param_values = pre_process_param_value(new_value)
    processed_param_values = [ new_value ]

    # TODO this check is already part of check_param_is_valid (which is called later in this method and when the request is created) - we do not want to check this three times...?
    if processed_param_values.size == 0
      raise RHCP::RhcpException.new("invalid value '#{new_value}' for parameter '#{@current_param.name}'")
    end
    
    processed_param_values.each do |value|
      request = RHCP::Request.new(@command_selected, @collected_values)
      @command_broker.check_param_is_valid(request, @current_param.name, [ value ])
      $logger.debug "accepted value #{value} for param #{@current_param.name}"

      @collected_values[@current_param.name] = Array.new if @collected_values[@current_param.name] == nil
      @collected_values[@current_param.name] << value
    end
    processed_param_values
  end
  
  def execute_command
    begin
      $logger.debug("(ShellBackend) gonna execute command '#{@command_selected.name}' on broker '#{@command_broker}'")
      command = @command_broker.get_command(@command_selected.name)
      request = RHCP::Request.new(command, @collected_values)
      response = @command_broker.execute(request)

      if (response.status == RHCP::Response::Status::OK)
        $logger.debug "raw result : #{response.data}"
        $logger.debug "result hints: #{command.result_hints}"
        $logger.debug "display_type : #{command.result_hints[:display_type]}"
        
        #if not command.result_hints.has_key? :display_type
        #  puts response.data.class
        #end
        
        @last_response = response
        if command.result_hints[:display_type] == "table"
          # we might want to access this response in further commands
          
          output = format_table_output(command, response)
          puts output
        elsif command.result_hints[:display_type] == "hash"
          output = format_hash_output(command, response)
          puts output
        elsif command.result_hints[:display_type] == "list"
          output = ""
          response.data.each do |row|
            output += "#{row}\n"
          end
          puts output
        elsif command.result_hints[:display_type] == "hidden"
          $logger.debug "suppressing output due to display_type 'hidden'"
        elsif command.result_hints[:display_type] == "raw"
          p output
        else
          if @prompt_color_enabled
            puts "#{green(@command_selected.name)} : #{response.data}"
          else
            puts "executed '#{@command_selected.name}' successfully : #{response.data}"
          end
        end
        
        # if the command has been executed successfully, we might have to update the prompt
        if @command_broker.context.cookies.has_key?('prompt')
          set_prompt @command_broker.context.cookies['prompt']
        end
        
      else
        if @command_selected.name == 'exit'
          $logger.debug "exiting on user request"
          Kernel.exit(0)
        end
        
        if @prompt_color_enabled
          puts "#{red(@command_selected.name)} : #{response.error_text}"
        else
          puts "could not execute '#{@command_selected.name}' : #{response.error_text}"
        end
        $logger.error "[#{@command_selected.name}] #{response.error_text} : #{response.error_detail}"
        
        set_prompt nil
      end
      reset_to_command_mode
    rescue
      error = $!
      if (error == "exit")
        puts "exiting"
        Kernel.exit
      else
        puts "got an error : >>#{$!}<<"
        raise
      end
    end
  end  
  
  ## the following methods are overridden from ShellBackend
  
  def process_input(command_line)
    $logger.debug "processing input '#{command_line}'"
    
    # we might have to setup the context aware broker for this thread
    Thread.current['broker'] = @command_broker
    
    begin
      if (@command_selected) then
        # we're in parameter processing mode - so check which parameter 
        # we've got now and switch modes if necessary
  
        # we might have been waiting for multiple param values - check if the user finished
        # adding values by selecting an empty string as value
        if (@current_param.allows_multiple_values and command_line == "") then
          $logger.debug "finished multiple parameter input mode for param #{@current_param.name}"
          @missing_params.shift        
          execute_command_if_possible
        else       
          accepted_params = add_parameter_value(command_line)
          if accepted_params
            # stop asking for more values if
            # a) the parameter does not allow more than one value
            # b) the user entered a wildcard parameter that has been expanded to multiple values
            if (! @current_param.allows_multiple_values or accepted_params.length > 1) then
              $logger.debug "finished parameter input mode for param #{@current_param.name}"
              @missing_params.shift        
              execute_command_if_possible
            else
              $logger.debug "param '#{@current_param.name}' expects multiple values...deferring mode switching"
            end
          end
        end
      else
        # we're waiting for the user to enter a command
        # we might have a command with params
        command, *params = command_line.split
        $logger.debug "got command '#{command}' (params: #{params})"
  
        # remember what the user specified so far
        begin
          @command_selected = @command_broker.get_command(command)
          #if (@command_selected != nil) then
          $logger.debug "command_selected: #{@command_selected}"
            
          # process the params specified on the command line          
          if (params != nil) then            
            params.each do |param|
              if param =~ /(.+?)=(.+)/ then
                # --> named param
                key = $1
                value = $2
              else
                # TODO if there's only one param, we can always use this as default param (maybe do this in the command?)
                # --> unnamed param
                value = param
                default_param = @command_selected.default_param
                if default_param != nil then
                  key = default_param.name
                  $logger.debug "collecting value '#{value}' for default param '#{default_param.name}'"
                else
                  $logger.info "ignoring param '#{value}' because there's no default param"
                end
              end
  
              if key then
                begin
                  @current_param = @command_selected.get_param(key)
                  add_parameter_value(value)
                rescue RHCP::RhcpException => ex
                  if @command_selected.accepts_extra_params
                    puts "collecting value for extra param : #{key} => #{value}"
                    @collected_values["extra_params"] = {} unless @collected_values.has_key?("extra_params")
                    @collected_values["extra_params"][key] = Array.new if @collected_values["extra_params"][key] == nil
                    @collected_values["extra_params"][key] << value
                  else
                    puts "ignoring parameter value '#{value}' for param '#{key}' : " + ex.to_s
                  end
                end
              end
            end
          end
                      
          $logger.debug "selected command #{@command_selected.name}" 
          execute_command_if_possible
        rescue RHCP::RhcpException => ex
          puts "#{ex}"
          reset_to_command_mode
        end
      end
    rescue RHCP::RhcpException => ex
      $logger.error ex
      puts "exception raised: #{ex.to_s}"
      reset_to_command_mode
    end
  end
  
  def complete(word = "")
    #$logger.debug "collecting completion values for '#{word}'"
    
    Thread.current['broker'] = @command_broker

    if (@command_selected) then
      $logger.debug("asking for lookup values for command '#{@command_selected.name}' and param '#{@current_param.name}'")
      request = RHCP::Request.new(@command_selected, @collected_values, @command_broker.context)
      props = @lookup_broker.get_lookup_values(request, @current_param.name)
    else
      props = @lookup_broker.get_command_list(@command_broker.context).values.map{|command| command.name}.sort
    end
    
    proposal_list = props.map { |p| "'#{p}'" }.join(" ")
    $logger.debug "completion proposals: #{proposal_list}"

    prefix = word
    props.select{|name|name[0...(prefix.size)] == prefix}
  end
  
  def show_banner
    puts @banner
  end
  
  def prompt
    if @current_param != nil
      "#{@command_selected.name}.#{@current_param.name} $ "
    else    
      @current_prompt || "$ "
      #"#{@current_prompt and @current_prompt != '' ? @current_prompt + " " : ""}$ "
    end
  end
  
  def set_prompt(string)
    @current_prompt = string    
  end
  
  def process_ctrl_c
    puts ""
    if @command_selected then
      reset_to_command_mode
    else
      Kernel.exit
    end
  end  
  
end
