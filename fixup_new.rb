require 'tiny_tds'
require 'fileutils'

class FixUp

  def go

    @host = "enreport.db.whatclinic.com"
    @db = "enreport"
    @username = "enreport"
    @password = "enreport"

    client = TinyTds::Client.new username: @username, password: @password, host: @host, database: @db

    source = read_file_to_array("fix_up_reviews_manilla.csv")
    fixed_file = "fixed_up_reviews_manilla.csv"
    File.delete(fixed_file) if File.exist?(fixed_file)

    fixed_array = []
    source.each do |row|
      arr_row = row.split(",")
      clinic_id = arr_row[0]
      table = arr_row[1]
      table_id = arr_row[2]

      # add the clinic name
      res = client.execute("select name from clinics where id = #{clinic_id}")
      arr_row << res.first["name"]

      # # add whether the reviews row is deleted or not
      # if (table == "reviews")
      #   res = client.execute("select status from reviews where id = #{table_id}")
      #   status = res.first["status"]
      #   if (status == 2 or status == 3)
      #     arr_row << "deleted"
      #   end
      # end
      #
      # if (table == "leadfeedback")
      #   res = client.execute("select ShowLeadFeedBack from leadfeedback where id = #{table_id}")
      #   status = res.first["ShowLeadFeedBack"]
      #   if (status == -1 or status == 2)
      #     arr_row << "deleted"
      #   end
      # end

      out = arr_row.join(",")
      puts out
      fixed_array << out
    end


    File.open(fixed_file, "w+") do |f|
      f.puts(fixed_array)
    end


  end


  def read_file_to_array(file_name)

    ret = []
    return ret unless (File.exists? file_name)

    f = File.open(file_name)

    f.each_line do |line|
      ret << line.gsub(/\n/, "")
    end

    return ret

  end

end

FixUp.new.go