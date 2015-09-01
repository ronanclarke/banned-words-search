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

    country = url.split("/")[4]
    return @country_path_mapping[country]

  end

  def check_urls
    urls = read_file_to_array("data/urls_to_check.db", true)

    puts "#{urls.size} urls to check "

    start_time = Time.now
    counter = 0

    #urls = [urls[0]]

    params = []
    params << "adwords=true"
    params << "adtest1=true"

    urls.each.each do |url|


      # add params as required to the url
      url = url + (url.include?("?") ? "&" : "?") + params.join("&")

      test_url_response(url)
      test_url_response(url, true) # send true so we fetch the mobile version using the cookie switch
      puts counter
      counter = counter + 1
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


  def get_country_mapping
    return {
        'uk' => 'GB', # daily occurence: 675735
        'ireland' => 'IE', # daily occurence: 175153
        'india' => 'IN', # daily occurence: 97870
        'australia' => 'AU', # daily occurence: 62191
        'philippines' => 'PH', # daily occurence: 56729
        'malaysia' => 'MY', # daily occurence: 53377
        'singapore' => 'SG', # daily occurence: 48206
        'canada' => 'CA', # daily occurence: 46373
        'mexico' => 'US', # daily occurence: 46136     rewritten from: MX
        'thailand' => 'TH', # daily occurence: 33414
        'turkey' => 'TR', # daily occurence: 32840
        'south-africa' => 'ZA', # daily occurence: 31915
        'united-arab-emirates' => 'AE', # daily occurence: 22687
        'spain' => 'ES', # daily occurence: 19140
        'poland' => 'PL', # daily occurence: 14108
        'egypt' => 'EG', # daily occurence: 12794
        'hungary' => 'HU', # daily occurence: 11543
        'us' => 'US', # daily occurence: 10223
        'south-korea' => 'KR', # daily occurence: 10183
        'cyprus' => 'CY', # daily occurence: 8688
        'romania' => 'RO', # daily occurence: 8479
        'indonesia' => 'ID', # daily occurence: 8267
        'belgium' => 'BE', # daily occurence: 6839
        'costa-rica' => 'US', # daily occurence: 6788      rewritten from: CR
        'czech-republic' => 'CZ', # daily occurence: 6641
        'new-zealand' => 'NZ', # daily occurence: 6500
        'vietnam' => 'VN', # daily occurence: 6167
        'switzerland' => 'CH', # daily occurence: 5701
        'greece' => 'GR', # daily occurence: 5620
        'germany' => 'DE', # daily occurence: 5311
        'bulgaria' => 'BG', # daily occurence: 5216
        'croatia' => 'HR', # daily occurence: 4829
        'malta' => 'MT', # daily occurence: 3938
        'hong-kong-sar' => 'HK', # daily occurence: 3915
        'lebanon' => 'LB', # daily occurence: 3690
        'dominican-republic' => 'DO', # daily occurence: 3275
        'macedonia' => 'MK', # daily occurence: 3229
        'brazil' => 'BR', # daily occurence: 2977
        'italy' => 'IT', # daily occurence: 2842
        'argentina' => 'AR', # daily occurence: 2755
        'serbia' => 'RS', # daily occurence: 2374
        'panama' => 'PA', # daily occurence: 2297
        'israel' => 'IL', # daily occurence: 2171
        'france' => 'FR', # daily occurence: 2108
        'latvia' => 'LV', # daily occurence: 2091
        'jordan' => 'JO', # daily occurence: 2032
        'nepal' => 'NP', # daily occurence: 2014
        'peru' => 'PE', # daily occurence: 2004
        'russia' => 'RU', # daily occurence: 1934
        'netherlands' => 'NL', # daily occurence: 1787
        'albania' => 'AL', # daily occurence: 1785
        'lithuania' => 'LT', # daily occurence: 1770
        'portugal' => 'PT', # daily occurence: 1727
        'ukraine' => 'UA', # daily occurence: 1491
        'guatemala' => 'GT', # daily occurence: 1481
        'pakistan' => 'PK', # daily occurence: 1383
        'tunisia' => 'TN', # daily occurence: 1188
        'estonia' => 'EE', # daily occurence: 1175
        'china' => 'CN', # daily occurence: 1094
        'colombia' => 'CO', # daily occurence: 1072
        'oman' => 'OM', # daily occurence: 978
        'saudi-arabia' => 'SA', # daily occurence: 954
        'slovakia' => 'SK', # daily occurence: 880
        'austria' => 'AT', # daily occurence: 871
        'georgia' => 'GE', # daily occurence: 854
        'japan' => 'JP', # daily occurence: 816
        'armenia' => 'AM', # daily occurence: 644
        'cambodia' => 'KH', # daily occurence: 600
        'syria' => 'SY', # daily occurence: 579
        'chile' => 'CL', # daily occurence: 557
        'cuba' => 'CU', # daily occurence: 552
        'tanzania' => 'TZ', # daily occurence: 550
        'mauritius' => 'MU', # daily occurence: 481
        'qatar' => 'QA', # daily occurence: 450
        'ecuador' => 'EC', # daily occurence: 375
        'slovenia' => 'SI', # daily occurence: 359
        'nicaragua' => 'NI', # daily occurence: 343
        'libya' => 'LY', # daily occurence: 294
        'isle-of-man' => 'IM', # daily occurence: 287
        'uruguay' => 'UY', # daily occurence: 286
        'bosnia-and-herzegovina' => 'BA', # daily occurence: 259
        'finland' => 'FI', # daily occurence: 250
        'iraq' => 'IQ', # daily occurence: 245
        'uganda' => 'UG', # daily occurence: 240
        'kenya' => 'KE', # daily occurence: 206
        'venezuela' => 'VE', # daily occurence: 201
        'montenegro' => 'ME', # daily occurence: 200
        'antarctica' => 'AQ', # daily occurence: 193
        'moldova' => 'MD', # daily occurence: 181
        'denmark' => 'DK', # daily occurence: 153
        'barbados' => 'BB', # daily occurence: 150
        'iran' => 'IR', # daily occurence: 143
        'bangladesh' => 'BD', # daily occurence: 127
        'sweden' => 'SE', # daily occurence: 122
        'liechtenstein' => 'LI', # daily occurence: 116
        'palestinian-authority' => 'PS', # daily occurence: 107
        'azerbaijan' => 'AZ', # daily occurence: 107
        'guernsey' => 'GG', # daily occurence: 107
        'gibraltar' => 'GI', # daily occurence: 102
        'ghana' => 'GH', # daily occurence: 86
        'st-lucia' => 'LC', # daily occurence: 80
        'puerto-rico' => 'PR', # daily occurence: 76
        'morocco' => 'MA', # daily occurence: 67
        'nigeria' => 'NG', # daily occurence: 62
        'haiti' => 'HT', # daily occurence: 44
        'norway' => 'NO', # daily occurence: 44
        'jersey' => 'JE', # daily occurence: 41
        'taiwan' => 'TW', # daily occurence: 39
        'kuwait' => 'KW', # daily occurence: 32
        'sri-lanka' => 'LK', # daily occurence: 24
        'trinidad-and-tobago' => 'TT', # daily occurence: 23
        'belarus' => 'BY', # daily occurence: 19
        'san-marino' => 'SM', # daily occurence: 18
        'martinique' => 'MQ', # daily occurence: 17
        'seychelles' => 'SC', # daily occurence: 9
        'el-salvador' => 'SV', # daily occurence: 8
        'mali' => 'ML', # daily occurence: 2
        'mongolia' => 'MN', # daily occurence: 2
        'united-states-minor-outlying-islands' => 'UM', # daily occurence: 2
        'yemen' => 'YE', # daily occurence: 1
        'kyrgyzstan' => 'KG', # daily occurence: 1
        'samoa' => 'WS', # daily occurence: 0
        'iceland' => 'IS', # daily occurence: 0
        'namibia' => 'NA', # daily occurence: 0
        'cameroon' => 'CM', # daily occurence: 0
        'afghanistan' => 'AF', # daily occurence: 0
    }

  end

end


CheckUrls.new.init
