#!/usr/bin/env ruby

require 'net/http'
require 'pathname'

if ARGV.size != 4
  puts 'Usage: fetch_oai.rb SET_NAME FROM UNTIL OUTPUT_DIRECTORY'
  exit
end

set_name = ARGV[0]
from = ARGV[1]
until_arg = ARGV[2]
output_dir = ARGV[3]

start = Time.new.to_f
batch_size = -1
count = 0
resumption_token = nil
keep_going = true

uri_str = "https://upenn.alma.exlibrisgroup.com/view/oai/01UPENN_INST/request?verb=ListRecords&set=#{set_name}&metadataPrefix=marc21&from=#{from}&until=#{until_arg}"
uri = URI(uri_str)
is_https = uri.scheme == 'https'

File.write(Pathname.new(output_dir).join('OAI_REQUEST'), "#{uri_str}\n")

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = is_https

http.start do |http_obj|
  http_obj.use_ssl = is_https
  http_obj.read_timeout = 300 # Default is 60 seconds
  while keep_going
    puts "Fetching #{uri}"
    request = Net::HTTP::Get.new(uri)
    response = http_obj.request(request)
    if response.code == '200'
      output = response.body

      basename = "#{set_name}_#{count.to_s.rjust(7, '0')}"
      output_filename = Pathname.new(output_dir).join("#{basename}.xml").to_s
      File.write(output_filename, output)
      match = output.match(%r{<resumptionToken>(.+)</resumptionToken>})
      resumption_token = match ? match[1] : nil

      # autodetect batch size
      if batch_size == -1
        batch_size = output.scan("<record>").size
      end

      rate = (Time.new.to_f - start) / ((count + 1) * batch_size)
      puts "overall rate: #{rate} records/s"

      count += 1

      uri = URI("https://upenn.alma.exlibrisgroup.com/view/oai/01UPENN_INST/request?verb=ListRecords&resumptionToken=#{resumption_token}")
      keep_going = !resumption_token.nil?
    else
      keep_going = false
    end
  end
end
