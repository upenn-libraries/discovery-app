#!/usr/bin/env ruby

if ARGV.size != 2
  puts "Usage: fetch_oai.rb SET_NAME OUTPUT_DIRECTORY"
  exit
end

set_name = ARGV[0]
output_dir = ARGV[1]

start = Time.new.to_f
batch_size = -1
count = 0
resumption_token = nil

loop do
  url = if resumption_token
          "https://upenn.alma.exlibrisgroup.com/view/oai/01UPENN_INST/request?verb=ListRecords&resumptionToken=#{resumption_token}"
        else
          "https://upenn.alma.exlibrisgroup.com/view/oai/01UPENN_INST/request?verb=ListRecords&set=#{set_name}&metadataPrefix=marc21"
        end
  puts "Fetching #{url}"
  output = `curl -s "#{url}"`
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

  break if !resumption_token
  count += 1
end
