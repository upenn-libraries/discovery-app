
# caches in memory and on disk
class RSSCache
  include Singleton

  def initialize
    @store = Hash.new
  end

  def tmp_path
    File.join(Rails.root, 'tmp')
  end

  def path_for_key(key)
    File.join(tmp_path, "rsscache_#{Digest::MD5.hexdigest(key)}")
  end

  # returns data for key, nil if nothing is cached
  def get(key)
    if !@store[key].present?
      path = path_for_key(key)
      if File.exists?(path)
        begin
          data = File.open(path, 'r') { |f| Marshal.load(f) }
          @store[key] = data
        rescue Exception => e
          Rails.logger.error("Something went wrong reading RSSCache file from disk: #{path} #{e}")
        end
      end
    end
    @store[key]
  end

  def store(key, data)
    File.open(path_for_key(key), 'wb') do |f|
      f.write(Marshal.dump(data))
    end
    @store[key] = data
  end

end

module RssProxy
  extend ActiveSupport::Concern

  # make an http request; this handles redirects
  def make_request(url, limit = 0)
    if limit > 5
      return nil
    end
    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri)

    http = Net::HTTP.new(uri.host, uri.port)
    # relatively short timeout to prevent taking up rails processes
    http.read_timeout = 5
    if uri.instance_of? URI::HTTPS
      http.use_ssl = true
    end
    response = http.request(req)

    if response.header['location']
      newurl = URI.parse(response.header['location'])
      if newurl.relative?
        newurl = url + response.header['location']
      end
      make_request(newurl.to_s, limit + 1)
    else
      response
    end
  end

  def rss_proxy(url, lifetime = 900)
    struct = RSSCache.instance.get(url)
    if !struct || (Time.now.to_i > struct[:timestamp] + lifetime)
      begin
        feed_response = make_request(url)
      rescue
        Rails.logger.warn("rss_proxy: error fetching URL: #{url}")
        Honeybadger.notify "Problem retrieving RSS content: #{feed_response.try :body}"
      end
      if feed_response
        struct = {
          content: feed_response.body,
          content_type: feed_response['Content-Type'],
          timestamp: Time.now.to_i,
        }
        RSSCache.instance.store(url, struct)
      end
    end
    response.headers['Content-Type'] = struct[:content_type]
    render text: struct[:content]
  end

end
