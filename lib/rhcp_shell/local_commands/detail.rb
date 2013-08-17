def add_detail_command(broker)

  command = RHCP::Command.new("detail", "shows details about a single record of the last response\n" + (" " * 43)  + "(makes sense if you executed a command that returned a table)",
    lambda { |req,res| 
      if @last_response == nil
        puts "did not find any old response data...is it possible that you did not execute a command yet that returned a table?"
        return
      end
      row_count = @last_response.data.length
      begin
        row_index = req.get_param_value("row_index").to_i
        raise "invalid index" if (row_index < 1 || row_index > row_count)
      rescue
        puts "invalid row index - please specify a number between 1 and #{row_count}"  
        return
      end
      puts "displaying details about row \# #{row_index}"
      @last_response.data[row_index - 1]          
      # @last_response.data[row_index - 1].each do |k,v|
        # puts "  #{k}\t#{v}"
      # end

    }
    ).add_param(RHCP::CommandParam.new("row_index", "the index of the row you want to see details about",
      {
        :is_default_param => true,
        :mandatory => true            
      }
    )
  )
  #command.result_hints[:display_type] = "hidden"
  command.result_hints[:display_type] = "hash"
  broker.register_command command
  
end  