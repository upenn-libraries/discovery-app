Alma.configure do |config|
  config.apikey = ENV['ALMA_API_KEY']
  config.timeout = 10
end
