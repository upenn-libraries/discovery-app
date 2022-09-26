#!/usr/bin/env ruby

# Does OAI requests to Alma using provided parameters.
# Ensure IP is allowlisted in Alma Integration Profile Configuration for OAI

require 'net/http'
require 'pathname'
require 'json'

if ARGV.size != 4
  puts 'Usage: fetch_oai.rb SET_NAME FROM UNTIL OUTPUT_DIRECTORY'
  puts '  set FROM and UNTIL to -1 to avoid sending those parameters'
  exit
end


# @param [String] message
def alert(message)
  puts message
  notify_slack message
end

# @param [String] message
def notify_slack(message)
  slack_uri = URI(ENV['SLACK_WEBHOOK_URL'])
  return unless slack_uri && message.present?

  http = Net::HTTP.new(slack_uri.host, slack_uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(slack_uri, 'Content-Type' => 'application/json')
  request.body = JSON.dump({ text: "OAI harvesting: #{message}" })
  puts http.request request
end

set_name = ARGV[0]
from_arg = ARGV[1]
until_arg = ARGV[2]
output_dir = ARGV[3]

start = Time.new.to_f
batch_size = -1
record_count = 0
request_count = 0
resumption_token = nil
keep_going = true

uri_str = "https://upenn.alma.exlibrisgroup.com/view/oai/01UPENN_INST/request?verb=ListRecords&set=#{set_name}&metadataPrefix=marc21"
if from_arg != '-1'
  uri_str += "&from=#{from_arg}"
end
if until_arg != '-1'
  uri_str += "&until=#{until_arg}"
end

uri = URI(uri_str)
is_https = uri.scheme == 'https'

File.write(Pathname.new(output_dir).join('OAI_REQUEST'), "#{uri_str}\n")

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = is_https

http.start do |http_obj|
  http_obj.use_ssl = is_https
  http_obj.read_timeout = 500 # Default is 60 seconds
  while keep_going
    puts "Fetching #{uri}"
    request = Net::HTTP::Get.new(uri)
    begin
      retries ||= 0
      response = http_obj.request(request)
    rescue Net::ReadTimeout => e
      puts "OAI request failed: #{e.message}"
      if (retries += 1) > 3
        puts 'Failed after 4 attempts'
      else
        retry
      end
    end
    if response.code == '200'
      output = response.body

      basename = "#{set_name}_#{request_count.to_s.rjust(7, '0')}"
      output_filename = Pathname.new(output_dir).join("#{basename}.xml.gz").to_s

      Zlib::GzipWriter.open(output_filename) do |gz|
        gz.write(output)
      end

      match = output.match(%r{<resumptionToken>(.+)</resumptionToken>})
      resumption_token = match ? match[1] : nil

      response_record_count = output.scan("<record>").count
      # autodetect batch size TODO: update this for accurate rate logging? first/last request might not have 500 (what is configured in Alma OAI integration config)
      if batch_size == -1
        batch_size = response_record_count
      end
      record_count += response_record_count

      elapsed = Time.new.to_f - start
      elapsed = elapsed > 0 ? elapsed : 1
      rate = ((request_count + 1) * batch_size) / elapsed
      puts "overall transfer rate: #{rate.to_i} records/s"
      puts "retrieved #{record_count} records so far"

      request_count += 1

      uri = URI("https://upenn.alma.exlibrisgroup.com/view/oai/01UPENN_INST/request?verb=ListRecords&resumptionToken=#{resumption_token}")
      keep_going = !resumption_token.nil?
    else
      puts 'Failed to get a successful response. Stopping.'
      notify_slack "Request failed! Bad response: #{response}"
      keep_going = false
    end
  end
end

duration = ((Time.new.to_f - start) / 60).round(1)
notify_slack "`fetch_oai.rb` complete. `#{record_count}` records harvested in #{duration} minutes."
