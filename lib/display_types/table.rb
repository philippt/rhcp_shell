def format_table_output(command, response)

    # TODO make sure that the response really holds the correct data types and that we've got at least one column
    # TODO check that all columns in overview_columns are valid
    # TODO check that all columns in column_titles are valid and match overview_columns
    output = ""         
    
    # let's find out which columns we want to display
    $logger.debug "overview columns : #{command.result_hints[:overview_columns]}"
    # TODO this will probably fail if no overview_columns are specified
    columns_to_display = command.result_hints.has_key?(:overview_columns) ?
      command.result_hints[:overview_columns].clone() :
      # by default, we'll display all columns, sorted alphabetically
      columns_to_display = response.data[0].keys.sort
    
    # and which titles they should have (default : column names)
    $logger.debug "column titles : #{command.result_hints[:column_titles].length}"
    column_title_list = command.result_hints[:column_titles].length > 0 ?
      command.result_hints[:column_titles].clone() :
      column_title_list = columns_to_display
    $logger.debug "column title list : #{column_title_list}"
    
    # TODO the sorting column should be configurable
    first_column = columns_to_display[0]
    $logger.debug "sorting by #{first_column}"
    response.data = response.data.sort { |a,b| a[first_column] <=> b[first_column] }          
    
    # add the index column
    columns_to_display.unshift "__idx"
    column_title_list.unshift "\#"
    count = 1
    response.data.each do |row|
      row["__idx"] = count
      count = count+1
    end
    
    column_titles = {}
    0.upto(column_title_list.length - 1) do |i|
      column_titles[columns_to_display[i]] = column_title_list[i]
    end
    $logger.debug "column titles : #{column_titles}"
    
    # initialize the max_width for all columns
    @max_width = {}
    column_titles.each do |key, value|
      @max_width[key] = 0
    end
    # find the maximum column width for each column
    response.data.each do |row|
      row.each do |k,v|
        if ! @max_width.has_key?(k) || v.to_s.length >  @max_width[k]
          @max_width[k] = v.to_s.length
        end
      end
    end
    
    # check the column_title for max width
    columns_to_display.each do |col_name|
      if column_titles[col_name].length > @max_width[col_name]
        @max_width[col_name] = column_titles[col_name].length
      end
    end
    #@max_width["row_count"] = response.data.length.to_s.length
    $logger.debug "max width : #{@max_width}"
    
    # and build headers
    @total_width = 2 + columns_to_display.length-1 # separators at front and end of table and between the values
    columns_to_display.each do |col|
      @total_width += @max_width[col] + 2 # each column has a space in front and behind the value
    end
    output += print_line
    
    columns_to_display.each do |col|
      output += print_cell(col, column_titles[col])
    end
    output += "|\n"

    output += print_line
    
    # print the table values
    response.data.each do |row|            
      columns_to_display.each do |col|
        output += print_cell(col, row[col])
      end
      output += "|\n"
    end
    output += print_line
  
end

def print_cell(col_name, the_value)
    result = "| "
    result += the_value.to_s
    1.upto(@max_width[col_name] - the_value.to_s.length) { |i| 
      result += " " 
    }
    result += " "
    result
  end
  
  def print_line
    result = ""
    @total_width.times { |i| result += "-" }
    result += "\n"
    result
  end