require 'tiny_tds'
require 'fileutils'
require "net/http"
require "uri"
require_relative 'common.rb'
require "json"

class GetBanned < Common


  def init()

    load_config


    process_index = 1
    process_count = 1

    puts "starting process #{process_index} of #{process_count}"
    @process_index = 1
    start_time = Time.now


    check_suppliers_pictures
    return

    # checking specific list of urls
    check_urls

    #find_bad_locations
    # find_bad_synonyms


    return

    clinics_to_process = get_clinics_to_process
    # clinics_to_process = [9027,18400]


    counter = 0
    begin
      clinics_to_process.each do |clinic_id|
        last_time = Time.now
        do_clinic_by_id(process_index, clinic_id)
        counter = counter + 1
        # puts Time.now - last_time
      end
      # rescue Exception => ex
      #   puts ex.message
      #   puts ex.backtrace.join("\n")
      #   puts
      #   puts "got a blowup restarting ....."
      #   init()
    end

    total_time = Time.now - start_time
    puts "total #{total_time},total records #{counter}, avg #{total_time / counter }"

  end

  def check_suppliers_pictures

    str_sql = "select id, filename,url from suppliers_pictures"

    client = TinyTds::Client.new username: @username, password: @password, host: @host, database: @db
    result = client.execute(str_sql)

    result.each do |result|
      to_check = [result["filename"],result["url"]]
      current_id = result["id"]
      to_check.each do |field|
        @compiled_regexes.each do |r|
          res = r.match(field)
          if res
            puts "found match for #{res[0]} in #{result["id"]} : #{field}"
          end
        end
      end
    end

  end



  def test_url(url)

    result = []
    hits= []

    @compiled_regexes.each do |r|
      url = url.gsub("-", " ")
      res = r.match(url)
      if res
        puts "got hit"
        hits << res[0]

      end


    end

    result = hits.size > 0 ? ["FAIL"] : ["PASS"]
    result << url
    result << hits.join("|")

    puts result.join(",")
  end

  def test_clinics_on_url(url)
    url_bust = url + "&cb=" + Time.now.to_i.to_s
    uri = URI.parse(url_bust)
    response = Net::HTTP.get_response(uri)
    puts response["X-WCC-META"]
    if !response
      puts "feck"
    end
    meta = JSON.parse(response["X-WCC-META"])
    clinics_to_scan = meta["clinics"].collect { |x| x["id"] }

    clinics_to_scan.each do |clinic_id|

      do_clinic_by_id(0, clinic_id)

    end

  end

  def get_clinics_to_process

    puts "getting list of clinics"

    source_array = read_file_to_array("logs-full-rescan-mon-22nd-Jun/bad_all.log", true)
    clinic_ids = []
    source_array.each do |row|
      clinic_ids << row.split(",")[1]
    end

    clinic_ids.uniq!


    # remove already completed ones
    completed_array = []
    file_name = "logs/results_completed_#{@process_index}.log"
    puts file_name
    if (File.exists? file_name)
      completed_array = read_file_to_array(file_name, true)
    end

    remaining = clinic_ids - completed_array

    puts "#{remaining.size} clinics remaining of #{clinic_ids.size} total"

    return remaining
  end

  def find_bad_synonyms
    synonyms = read_file_to_array("data/all_synonyms.db", true)

    puts synonyms.size


    synonyms.each do |synonym|

      @compiled_regexes.each do |r|

        res = r.match(synonym)
        if res

          str = "synonym:: '#{synonym}' match for ==>  #{res[0]}"
          puts str


        end
      end

    end
  end

  def find_bad_locations

    locations = read_file_to_array("data/all_locations.db", true)

    puts locations.size


    locations.each do |location|

      @compiled_regexes.each do |r|

        res = r.match(location)
        if res

          str = "location:: #{location} match for ==>  #{res[0]}"
          puts str


        end
      end

    end
  end


end

a = GetBanned.new
a.init