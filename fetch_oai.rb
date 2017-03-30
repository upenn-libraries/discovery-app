#!/usr/bin/env ruby

require 'net/http'
require 'pathname'

if ARGV.size != 3
  puts "Usage: fetch_oai.rb SET_NAME FROM OUTPUT_DIRECTORY"
  exit
end

set_name = ARGV[0]
from = ARGV[1]
output_dir = ARGV[2]

start = Time.new.to_f
batch_size = -1
count = 0
resumption_token = nil
keep_going = true

uri = URI("https://upenn.alma.exlibrisgroup.com/view/oai/01UPENN_INST/request?verb=ListRecords&set=#{set_name}&metadataPrefix=marc21&from=#{from}")

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = (uri.scheme == "https")

http.start do |http_obj|
  http_obj.use_ssl = (uri.scheme == "https")
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
