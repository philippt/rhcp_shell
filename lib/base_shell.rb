# This class is an abstract implementation of a command shell
# It handles command completion and history functions.
# For the actual business logic, you need to pass it an implementation of ShellBackend
class BaseShell
  attr_reader :backend
  
  def initialize(backend)    
    @logger = $logger
    @backend = backend
    
    at_exit { console.close }
    
    trap("INT") { 
      Thread.kill(@thread)
      @backend.process_ctrl_c
    }
  end
    
  class SimpleConsole
    def initialize(input = $stdin)
      @input = input
    end

    def readline
      begin
        line = @input.readline
        line.chomp! if line
        line
      rescue EOFError
        nil
      end
    end

    def close
    end
  end

  class ReadlineConsole
    HISTORY_FILE = ".jscmd_history"
    MAX_HISTORY = 200

    def history_path
      File.join(ENV['HOME'] || ENV['USERPROFILE'], HISTORY_FILE)
    end

    def initialize(shell)
      @shell = shell
      if File.exist?(history_path)
        hist = File.readlines(history_path).map{|line| line.chomp}
        Readline::HISTORY.push(*hist)
      end
      if Readline.methods.include?("basic_word_break_characters=")        
        #Readline.basic_word_break_characters = " \t\n\\`@><=;|&{([+-*/%"
        Readline.basic_word_break_characters = " \t\n\\`@><=;|&{([+*%"
      end
      Readline.completion_append_character = nil
      Readline.completion_proc = @shell.backend.method(:complete).to_proc
    end

    def close
      open(history_path, "wb") do |f|
        history = Readline::HISTORY.to_a
        if history.size > MAX_HISTORY
          history = history[history.size - MAX_HISTORY, MAX_HISTORY]
        end
        history.each{|line| f.puts(line)}
      end
    end

    def readline
      line = Readline.readline(@shell.backend.prompt, true)
      Readline::HISTORY.pop if /^\s*$/ =~ line
      line
    end
  end

  def console
    @console ||= $stdin.tty? ? ReadlineConsole.new(self) : SimpleConsole.new
  end
  
  def run
    backend.show_banner
    loop do      
      @thread = Thread.new {
          break unless line = console.readline
    
          if line then
            @logger.debug "got : #{line}"
          else
            @logger.debug "got an empty line"      
          end

          backend.process_input line
      }
      begin
        @thread.join
      rescue
        error = $!
        if error == "exit"
          puts "exiting"
          Kernel.exit
        else
          puts "got an error in @thread.join: #{error}"
        end
        
      end
      
    end
    $stderr.puts "Exiting shell..."      
  end
  
end
