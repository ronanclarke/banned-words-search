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
    @banned_keywords = get_banned_keywords

    @country_path_mapping = get_country_mapping

    check_urls
  end

  def get_country_header_for_url(url)

    country = url.split(/[\/\?]/)[4]
    return @country_path_mapping[country]

  end

  def check_urls
    urls = read_file_to_array("data/urls_to_check.db", true)

    puts "#{urls.size} urls to check "

    start_time = Time.now
    @counter = 0

    url = "http://www.whatclinic.com/cosmetic-plastic-surgery/hungary"
    urls = [url]

    puts get_country_header_for_url(url)

    params = []
    params << "adwords=true"
    params << "adtest1=true"

    urls.each.each do |url|


      # add params as required to the url
      url = url + (url.include?("?") ? "&" : "?") + params.join("&")

      test_url_response(url)
      test_url_response(url, true) # send true so we fetch the mobile version using the cookie switch
      puts @counter
      @counter = @counter + 1
    end
    end_time = Time.now

    puts "time taken #{end_time-start_time} for #{urls.size} urls (#{(end_time-start_time)/urls.size}/per url)"
  end

  def test_url_response(url, as_mobile = false)

    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, 80)
    request = Net::HTTP::Get.new(uri.request_uri)

    cookie = ""
    cookie = cookie + "cd=M;" if as_mobile # pass mobile cookie to force mobile if required
    cookie = cookie + "cc=#{get_country_header_for_url(url)}"

    request["Cookie"]=cookie
    request["x-request-id"] = "run1-" + @counter.to_s

    puts cookie

    response = http.request(request)

    version = as_mobile ? "mobile" : "desktop"

    if response.code.to_s != "200"
      log_to_file("fails", "#{version},non-200,#{url} , response code:: #{response.code}")
      log_to_file("result_for_page_scan", "#{version},#{url}, non-200,#{response.code}")
      return
    end

    body = response.body

    result = [url]
    hits= []

    @compiled_regexes.each do |r|

      res = r.match(body)
      if res
        puts "got hit for #{res[0]} in page #{url}"

        log_to_file("fails", "#{version},banned-term,#{url} , #{res[0]}")
        hits << res[0]


      end
    end


    if (hits.size > 0)
      log_to_file("result_for_page_scan", "#{version},#{url},banned-term, #{hits.join('|')}")
    else
      log_to_file("result_for_page_scan", "#{version},#{url},ok")
    end

    result = hits.size > 0 ? ["FAIL"] : ["PASS"]
    result << version
    result << url
    result << hits.join("|")

    puts result.join(",")

  end


end


CheckUrls.new.init
