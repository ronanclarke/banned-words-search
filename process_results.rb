require 'tiny_tds'
require 'fileutils'
class ProcessResults

  def go


    @host = "enreport.db.whatclinic.com"
    @db = "enreport"
    @username = "enreport"
    @password = "enreport"

    file_name = "logs/results_completed_0.log"

    #res = read_file_to_array(file_name)
    @log_dir = File.join(File.dirname(__FILE__), "logs")

    puts @log_dir
    #puts res.size

    @priority_clinics = read_file_to_array("dave_list_of_priority_clinics.txt",true)
    puts "count of priority clinics #{@priority_clinics.size}"




    combine_files("completed")
    combine_files("bad", true)
    combine_files("clean")


  end

  def go2

  end

  def combine_files(type, populate_suppliers =false)

    combined_file = "#{@log_dir}/#{type}_all.log"
    File.delete(combined_file) if File.exist?(combined_file)

    files = Dir.glob("#{@log_dir}/*#{type}*.log")

    all = []
    files.each do |file|
      all += read_file_to_array(file)
    end


    puts "original length : #{all.size}"
    all= all.uniq
    puts "deduped length  : #{all.size}"

    if (populate_suppliers)
      # populate extra info from suppliers
      all_updated = []
      client = TinyTds::Client.new username: @username, password: @password, host: @host, database: @db


      all.each_with_index  do |each,i|

        clinic_id = each.split(",")[0].to_i
        result = client.execute("select s.Id as supplierId,s.SupplierType,s.TermsID  FROM Clinics c JOIN Suppliers s ON c.supplierid = s.id where c.ID = #{clinic_id}")
        res = result.first

        if (res)

          is_priority = @priority_clinics.include? clinic_id.to_s

          if (res["SupplierType"] && res["SupplierType"] == 2)
            supplierType = "Paid"
          else
            supplierType = "Free"
          end

          termsAccepted = res["TermsID"] ? "Yes" : "No"



          prepend = [is_priority, res["supplierId"], supplierType, termsAccepted].join(",")
          each = prepend + "," + each
          puts each
          all_updated << each
        else
          puts "res is nil for #{clinic_id}"
          break
        end

        File.open("bad_all_with_extra_info", "w+") do |f|
          f.puts(all_updated)
        end

      end

      client.close

    end

    File.open(combined_file, "w+") do |f|
      f.puts(all)
    end
  end

  def read_file_to_array(file_name,remove_newlines = false)

    ret = []
    return ret unless (File.exists? file_name)

    f = File.open(file_name)

    f.each_line do |line|

      if(remove_newlines)
        ret << line.gsub(/\n/,"")
      else

        ret << line
      end
    end

    return ret

  end

end

ProcessResults.new.go2
