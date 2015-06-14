class ProcessResults

  def go

    file_name = "logs/results_completed_0.log"

    #res = read_file_to_array(file_name)
    @log_dir = File.join(File.dirname(__FILE__), "logs")

    puts @log_dir
    #puts res.size

    combine_files("completed")
    combine_files("bad")
    combine_files("clean")


  end

  def combine_files(type)

    combined_file = "#{@log_dir}/#{type}_all.log"
    File.delete(combined_file) if File.exist?(combined_file)

    files = Dir.glob("#{@log_dir}/*#{type}*.log")

    all = []
    files.each do |file|
      all += read_file_to_array(file)
    end

    puts "original length : #{all.size}"
    all= all.uniq.sort
    puts "deduped length  : #{all.size}"





    File.open(combined_file, "w+") do |f|
      f.puts(all)
    end
  end

  def read_file_to_array(file_name)

    ret = []
    return ret unless (File.exists? file_name)

    f = File.open(file_name)

    f.each_line do |line|
      ret << line
    end

    return ret

  end

end

ProcessResults.new.go
