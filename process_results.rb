require 'tiny_tds'
require 'fileutils'
class ProcessResults

  def go


    @host = "enreport.db.whatclinic.com"
    @db = "enreport"
    @username = "enreport"
    @password = "enreport"

    @host = "prod.windows.whatclinic.net"
    @db = "prod"
    @username = "prod"
    @password = "prod"


    file_name = "logs/results_completed_0.log"

    #res = read_file_to_array(file_name)
    # @log_dir = File.join(File.dirname(__FILE__), "logs-full-rescan-mon-22nd-Jun")
    #@log_dir = File.join(File.dirname(__FILE__), "2nd-set-of-words/full-rescan-6th-Jul-2015/")
    @log_dir = File.join(File.dirname(__FILE__), "logs")

    puts @log_dir
    #puts res.size


    combine_files("completed")
    combine_files("bad", false)
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


      all.each_with_index do |each, i|

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

    whitelisted_terms = ["hawthorn","artane"]
    final = []
    all_terms = []
    if (type == "bad")
      all.each_with_index do |each, i|
        term = each.split(",")[5].to_s
        term.downcase!
        # get counts of duplicates



        all_terms << term
        if (!whitelisted_terms.include? term)
          final << each
        end
      end

      all_terms = all_terms - whitelisted_terms
      grouped = all_terms.inject(Hash.new(0)) { |h, e| h[e] += 1 ; h }
      sorted = grouped.sort_by { |name,count| count * -1}
      sorted.each do |item|
        puts "#{item[0]} #{item[1]}"
      end
    end

    if (final.size > 0)
      all = final
    end


    File.open(combined_file, "w+") do |f|
      f.puts(all)
    end
  end

  def read_file_to_array(file_name, remove_newlines = false)

    ret = []
    return ret unless (File.exists? file_name)

    f = File.open(file_name)

    f.each_line do |line|

      if (remove_newlines)
        ret << line.gsub(/\n/, "")
      else

        ret << line
      end
    end

    return ret

  end

end

ProcessResults.new.go
