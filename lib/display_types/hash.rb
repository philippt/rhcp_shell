def format_hash_output(command, response)
  output = []
  
  max_key_length = response.data.keys().sort { |a,b| a.length <=> b.length }.first.length
  
  response.data.each do |k,v|
    output << sprintf("  %-#{max_key_length + 5}s\t%s", k, v)
  end
  output.join("\n")
end