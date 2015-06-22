require 'tiny_tds'
require 'fileutils'
require_relative 'common.rb'

class GetBanned < Common


  def init()

    load_config

    process_index = 1
    process_count = 1

    puts "starting process #{process_index} of #{process_count}"
    @process_index = 1

    clinics_to_process = get_clinics_to_process


    start_time = Time.now
    counter = 0
    begin
      clinics_to_process.each do |clinic_id|
        last_time = Time.now
        do_clinic_by_id(process_index, clinic_id)
        counter = counter + 1
        puts Time.now - last_time
      end
    rescue Exception => ex
      puts ex.message
      puts ex.backtrace.join("\n")
      puts
      puts "got a blowup restarting ....."
      init()
    end

    total_time = Time.now - start_time
    puts "total #{total_time},total records #{counter}, avg #{total_time / counter }"

  end

  def get_clinics_to_process


    return [163158,
            166378,
            166314,
            162385,
            160858,
            171684,
            171783,
            171879,
            174380,
            168221,
            168217,
            168218,
            168230,
            168225,
            168226,
            168207,
            168205,
            168213,
            168215,
            168212,
            168235,
            168234,
            168233,
            168244,
            168242,
            168241,
            168201,
            168160,
            168155,
            168156,
            168157,
            168167,
            168166,
            168163,
            168165,
            168146,
            168141,
            168142,
            168151,
            168152,
            168147,
            168149,
            168190,
            168191,
            168192,
            168189,
            168186,
            168187,
            168197,
            168198,
            168196,
            168193,
            168195,
            168174,
            168175,
            168173,
            168170,
            168172,
            168182,
            168181,
            168177,
            168180,
            168101,
            168103,
            168099,
            168096,
            168097,
            168098,
            168108,
            168109,
            168095,
            168085,
            168086,
            168084,
            168081,
            168082,
            168083,
            168092,
            168093,
            168094,
            168091,
            168089,
            168090,
            168131,
            168132,
            168127,
            168128,
            168137,
            168138,
            168139,
            168136,
            168134,
            168135,
            168125,
            168115,
            168116,
            168117,
            168114,
            168111]


    puts "getting list of clinics"

    source_array = read_file_to_array("logs-sun-14th-evening/bad_all.log", true)
    clinic_ids = []
    source_array.each do |row|
      clinic_ids << row.split(",")[0]
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



end

a = GetBanned.new
a.init