require 'tiny_tds'
require 'fileutils'
require_relative 'common.rb'

class GetBanned < Common


  def init(procces_count=nil, process_index=nil)

    # parse arguments


    unless procces_count and process_index
      if ARGV.size < 2
        puts "please enter 2 args ...  processes, index "
        return
      else
        process_count = ARGV[0].to_i
        process_index = ARGV[1].to_i
      end
    end


    load_config

    @compiled_regexes = []

    @batch_counter = 0
    @total = 0
    @start_time = Time.now

    client = TinyTds::Client.new username: @username, password: @password, host: @host, database: @db
    result = client.execute("SELECT  max(row_num) as maxid
                              FROM (SELECT row_number() OVER ( ORDER BY c.id) AS row_num, c.id
                                     FROM Clinics c JOIN Suppliers s ON c.supplierid = s.id AND s.status != 0
                                    ) as sub    ")
    max_id = result.first["maxid"]

    client.close

    range_size = (max_id / process_count-1).to_i
    ranges = [0]
    val_to_insert = range_size
    while (val_to_insert < max_id)
      ranges << val_to_insert
      val_to_insert += range_size
    end
    ranges[ranges.size-1] = max_id

    puts "starting process #{process_index} of #{process_count}"

    process_count.times do |i|
      puts "#{i} #{ranges[i]} - #{ranges[i+1]}"
    end
    @process_index = process_index



    begin
      do_batch_of_clinics(process_index, ranges[process_index], ranges[process_index+1])
     rescue
       puts "got a blowup restarting ....."
      init(procces_count,process_index)
    end


  end

  def do_batch_of_clinics(i, range_start=0, range_end=1000000000)

    @process_index = i
    str = "process #{Process.pid} starting on range #{range_start} - #{range_end}"
    puts str
    log_to_file("init", str, false)
    @banned_keywords.each do |keyword|
      @compiled_regexes << Regexp.new(/\b#{keyword}\b/i)
    end

    last_id = range_start

    # check for completed clinics and set last_id to that
    last_id = check_for_completed_clinics(last_id)
    puts "lastid is #{last_id}"
    empty_iterations = 0
    # keep looping till we do out entire section
    while (last_id < range_end) do

      batch_size = 50
      counter = 0
      start_time = Time.now


      client = TinyTds::Client.new username: @username, password: @password, host: @host, database: @db
      cols = @clinic_cols


      clinics_sql = "SELECT row_num,ID,supplierId,Id as clinicId,#{cols.join(",")}
                      FROM (SELECT  row_number() OVER (ORDER BY c.id) AS row_num,
                      c.id,c.supplierId as supplierId,c.#{cols.join(",c.")}
                      FROM Clinics c JOIN Suppliers s ON c.supplierid = s.id AND s.status != 0
                      ) as sub
                      where row_num > #{last_id} and row_num <= #{last_id.to_i + batch_size}"

      # clinics_sql = "SELECT top #{batch_size} c.id as clinicId,c.ID as ID,c.supplierId as supplierId,#{cols.join(',')}
      #               from Clinics c join Suppliers s on c.supplierid = s.id where c.id > #{last_id} and c.id <= #{range_end} and s.status != 0  order by c.id "

      result = client.execute(clinics_sql)

      if result.count < 1
        last_id = last_id.to_i + batch_size.to_i
        empty_iterations += 1
      end
      if(empty_iterations > 50)
        puts "too many empty records breaking"
        last_id = range_end
      end
      # process each clinic
      result.each do |row|
        test_clinic_row(row, cols)
        last_id = row["row_num"].to_i
        log_to_file("completed", last_id)
      end

      client.close

      # just stats here
      @total = @total + result.count
      now = Time.now
      if (!@last_time)
        @last_time = Time.now
      end
      puts "#{@process_index} last_id #{last_id} (#{range_start}|#{range_end}) remaining #{range_end - last_id}- total processed = #{@total} : #{now - @start_time} : lap = #{now-@last_time}"
      @last_time = Time.now

      @batch_counter = @batch_counter + 1


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

a = GetBanned.new
a.init