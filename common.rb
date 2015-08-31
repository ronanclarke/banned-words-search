class Common

  def load_config
    puts "loading config"

    @host = "enreport.db.whatclinic.com"
    @db = "enreport"
    @username = "enreport"
    @password = "enreport"

    @host = "staging.windows.whatclinic.net"

    @db = "wcc"
    @username = "local"
    @password = "local"

    # @host = "prod.db.whatclinic.com"
    # @db = "prod"
    # @username = "prod"
    # @password = "prod"

    @run_time_stamp = Time.now.strftime("%m-%d_%H-%M-%S")
    # columns under test
    @clinic_cols = ["name", "shortdescription", "longdescription", "Address1", "Address2", "City", "State", "PostalCode"]
    @treatment_cols = ["treatment", "details"]
    @staff_cols = ["BioHTML", "Name", "LastName", "Additional_Notes", "Premises", "Special_Interests"]
    @feedback_cols = ["Comments"]
    @reviews_cols = ["UserName", "TEXT", "Title", "staffname", "YouRecommend", "YouReturn", "PlaceName", "HowTravel", "ClinicsResponse", "TreatmentName", "ClinicComment"]
    @service_cols = ["Description"]
    @banned_keywords = get_banned_keywords


    FileUtils::mkdir_p "logs" # make a dir to hold our logs

    @compiled_regexes = []
    @banned_keywords.each do |keyword|
      @compiled_regexes << Regexp.new(/\b#{keyword}\b/i)
    end
    @batch_counter = 0
    @total = 0
    @start_time = Time.now

  end

  def log_to_file(file_type, log_text, with_process=true)

    if (with_process)
      file_name = "logs/results_#{file_type}_#{@process_index}.log"
    else
      file_name = "logs/results_#{file_type}.log"
    end

    open(file_name, 'a') do |f|
      f.puts "#{log_text}"
    end


  end

  def check_for_completed_clinics(orig_id)


    file_name = "logs/results_completed_#{@process_index}.log"
    return orig_id unless (File.exists? file_name)
    res = IO.readlines(file_name)[-1]

    puts "should restart from id #{res}"
    return res.to_i

  end

  def do_clinic_by_id(i, clinic_id)
    @process_index = i

    client = TinyTds::Client.new username: @username, password: @password, host: @host, database: @db
    cols = @clinic_cols

    clinics_sql = "SELECT row_num,ID,supplierId,Id as clinicId,#{cols.join(",")}
                      FROM (SELECT  row_number() OVER (ORDER BY c.id) AS row_num,
                      c.id,c.supplierId as supplierId,c.#{cols.join(",c.")}
                      FROM Clinics c JOIN Suppliers s ON c.supplierid = s.id AND s.status != 0
                      ) as sub
                      where ID = #{clinic_id}"


    result = client.execute(clinics_sql)
    row = result.first

    puts "processing clinic id #{clinic_id}"
    if (row && row["name"])
      test_clinic_row(row, cols)
      last_id = row["clinicId"].to_i
      log_to_file("completed", last_id)
    else
      log_to_file("not_found_clinics", clinic_id)
    end


  end

  #
  # do this once per clinic
  #
  def test_clinic_row(row, cols)


    @batch_results = []
    is_bad_clinic = false
    str = ""
    cols.each do |col|

      str = str + " #{row[col]}"
    end

    # check the clinic table itself
    if (is_hit?(str))

      cols.each do |col|
        if (test_field(row, "clinics,#{col}", row[col]))
          is_bad_clinic = true
        end
      end
    end

    # check treatments
    is_bad_clinic = true if check_treatments_for_clinic(row["ID"])

    # check staff
    is_bad_clinic = true if check_staff_for_clinic(row["ID"])

    # check feedback
    is_bad_clinic = true if check_feedback_for_clinic(row["ID"])

    # reviews
    is_bad_clinic = true if check_reviews_for_clinic(row["ID"])

    # clinic services
    is_bad_clinic = true if check_services_for_clinic(row["ID"])

    # log the result
    @batch_results << {result: :clean, message: row["ID"], clinic_id: row["ID"]} unless is_bad_clinic

    @batch_results.each do |result|
      log_to_file(result[:result].to_s, "#{row["supplierId"]},#{result[:message]},#{row["name"].to_s.gsub(",", "")}")
    end

  end

  # table specific logic to build queries

  def check_staff_for_clinic(clinic_id)
    str_sql = " select cs.clinicId as clinicId,s.id as ID,#{@staff_cols.join(",") } from Staffs s join clinics_staff cs on cs.StaffID = s.id where s.Status = 1 and cs.ClinicID = #{clinic_id}"
    return check_rows_for_clinic("Staffs", str_sql, @staff_cols)
  end

  def check_treatments_for_clinic(clinic_id)

    str_sql = "select cpp.clinicid as clinicId ,cpp.id as ID , coalesce(cpp.treatment, '') as treatment, coalesce(cpp.details, '') as details
                from
                Clinic_ProcedurePricing cpp
                join Procedures p on p.id = cpp.procid
                where
                cpp.clinicid = #{clinic_id} and cpp.status = 1 and p.status = 0
                and not (coalesce(cpp.treatment, p.name) = p.name and len(coalesce(cpp.details, '')) = 0) "

    return check_rows_for_clinic("Clinic_ProcedurePricing", str_sql, @treatment_cols)
  end

  def check_feedback_for_clinic(clinic_id)
    str_sql = "select ce.ClinicId as clinicId,lf.id as ID, #{@feedback_cols.join(",")} from LeadFeedBack lf join Clinics_Enquiries ce on ce.id = lf.Clinics_EnquiryID where lf.status in(0,1) and ce.ClinicID = #{clinic_id} and LEN(coalesce(lf.comments,''))>0"
    return check_rows_for_clinic("leadfeedback", str_sql, @feedback_cols)
  end

  def check_reviews_for_clinic(clinic_id)
    cols = @reviews_cols.clone
    cols.delete("TreatmentName") # remove this special case here cos we compute it in SQL
    str_sql = "select clinicid as clinicId, id as ID,CASE WHEN(coalesce(cast(reviewlongtreatment as nvarchar),'')!='') then reviewlongtreatment else TreatmentName end as TreatmentName, #{@reviews_cols.join(",")} from Reviews where status in (0,1,4,5) and clinicId = #{clinic_id}"

    return check_rows_for_clinic("reviews", str_sql, cols)
  end

  def check_services_for_clinic(clinic_id)
    cols = @reviews_cols.clone
    cols.delete("TreatmentName") # remove this special case here cos we compute it in SQL
    str_sql = "select clinicid as clinicId, id as ID, #{@service_cols.join(",")} from clinics_services where clinicId = #{clinic_id}"
    return check_rows_for_clinic("clinics_services", str_sql, @service_cols)

  end

  # generic processing for query and individual rows
  def check_rows_for_clinic(table, str_sql, cols)
    ret = false

    client = TinyTds::Client.new username: @username, password: @password, host: @host, database: @db
    result = client.execute(str_sql)

    str = ""

    result.each do |row|
      cols.each do |col|
        str = str + " #{row[col]}"
      end
    end

    if is_hit?(str)
      ret = true
      # now check each one for a hit
      result.each do |row|
        check_single_row(table, row, cols)
      end

    end

    client.close

    return ret

  end

  def check_single_row(table, row, cols)

    ret = false
    cols.each do |col|
      if (table == 'reviews' && col.downcase == 'treatmentname' && row[''])
        ret = test_field(row, "#{table},#{col}", row[col])
      end

      return ret
    end
  end

  # actually do the regex operations
  def is_hit?(str)
    ret = false

    @compiled_regexes.each do |r|

      res = r.match(str)

      if res # break and return early on first hit
        ret = true
        break
      end
    end
    return ret

  end

  def test_field(row, field, val)
    ret = false
    @compiled_regexes.each do |r|

      res = r.match(val)
      if res

        str = "clinicId: #{row["clinicId"]}  id #{row["ID"]} field #{field} match for ==>  #{res[0]}"
        log_str = "#{row["clinicId"]},#{row["ID"]},#{field},#{res[0]}"
        puts str
        ret = true
        @batch_results << {clinic_id: row["clinicId"], result: :bad, message: log_str}
        # log_to_file('bad_clinics', log_str)

      end
    end
    return ret
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


  def get_banned_keywords

    banned1 = read_file_to_array("data/banned_words_list_1.db",true)
    banned2 = read_file_to_array("data/banned_words_list_2.db",true)
    return banned1 + banned2

  end
end