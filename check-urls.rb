require 'tiny_tds'
require 'fileutils'
require "net/http"
require "uri"
require_relative 'common.rb'
require "json"

# load some config stuff and helper methods from common.rb
class CheckUrls < Common


  def init()


    load_config # load the config e.g. what db to talk to etc
    get_banned_keywords


  end

  def check_urls
    urls = read_file_to_array("urls-to-check.db", true)


    start_time = Time.now
    counter = 0
    urls.each.each do |url|

      puts counter
      counter = counter + 1
      puts "testing #{url}"
      # test_clinics_on_url(url)
      test_url_response(url)
      # test_url(url)


    end
    end_time = Time.now

    puts "time taken #{end_time-start_time} for #{urls.size} urls (#{(end_time-start_time)/urls.size}/per url)"
  end

  def test_url_response(url)
    url_bust = url + "&cd=M&cb=" + Time.now.to_i.to_s
    puts url_bust
    uri = URI.parse(url_bust)
    response = Net::HTTP.get_response(uri)

    if response.code.to_s != "200"
      log_to_file("fails", "non-200,#{url_bust} , response code:: #{response.code}")
      log_to_file("result_for_page_scan", "#{url_bust}, non-200,#{response.code}")
      return
    end

    last_start = Time.now
    body = response.body

    result = [url]
    hits= []

    @compiled_regexes.each do |r|

      res = r.match(body)
      if res
        puts "got hit for #{res[0]} in page #{url}"

        log_to_file("fails", "banned-term,#{url} , #{res[0]}")
        hits << res[0]


      end
    end

    if (hits.size > 0)
      log_to_file("result_for_page_scan", "#{url_bust},banned-term, #{hits.join('|')}")
    else
      log_to_file("result_for_page_scan", "#{url_bust},ok")
    end

    result = hits.size > 0 ? ["FAIL"] : ["PASS"]
    result << url
    result << hits.join("|")

    puts result.join(",")

  end

end


CheckUrls.new.init
