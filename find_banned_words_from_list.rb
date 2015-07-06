require 'tiny_tds'
require 'fileutils'
require "net/http"
require "uri"
require_relative 'common.rb'

class GetBanned < Common


  def init()

    load_config


    process_index = 1
    process_count = 1

    puts "starting process #{process_index} of #{process_count}"
    @process_index = 1
    start_time = Time.now
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

  def check_urls
    urls = read_file_to_array("urls-to-check.db", true)


    start_time = Time.now

    urls.each.each do |url|
      test_url_response(url)
      # test_url(url)


    end
    end_time = Time.now

    puts "time taken #{end_time-start_time} for #{urls.size} urls (#{(end_time-start_time)/urls.size}/per url)"
  end

  def test_url(url)

    result = []
    hits= []

    @compiled_regexes.each do |r|
      url = url.gsub("-"," ")
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

  def test_url_response(url)
    url_bust = url + "&cb=" + Time.now.to_i.to_s
    uri = URI.parse(url_bust)
    response = Net::HTTP.get_response(uri)
    

    last_start = Time.now
    body = response.body

    result = [url]
    hits= []
    @compiled_regexes.each do |r|

      res = r.match(body)
      if res
        # puts "got hit for #{res[0]} in page #{url}"
        hits << res[0]
      end
    end

    result = hits.size > 0 ? ["FAIL"] : ["PASS"]
    result << url
    result << hits.join("|")

    puts result.join(",")

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
    synonyms = read_file_to_array("all-synonyms.db", true)

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

    locations = read_file_to_array("all_locations.db", true)

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