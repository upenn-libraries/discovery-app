# frozen_string_literal: true

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
    unless @store[key].present?
      path = path_for_key(key)
      if File.exists?(path)
        begin
          data = File.open(path, 'r') { |f| Marshal.load(f) }
          @store[key] = data
        rescue Exception => e
          Honeybadger.notify("Something went wrong reading RSSCache file from disk: #{path} #{e}")
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
  # @param [String] url
  # @param [Fixnum] limit
  def make_request(url, limit = 0)
    return nil if limit > 5

    Typhoeus.get url, followlocation: true, connecttimeout: 5
  rescue StandardError => e
    Honeybadger.notify "Problem retrieving RSS content: #{e.message}"
  end

  # @param [String] url
  # @param [Fixnum] lifetime
  def rss_proxy(url, lifetime = 900)
    data = RSSCache.instance.get(url)
    if !data || (Time.now.to_i > data[:timestamp] + lifetime)
      feed_response = make_request(url)
      if feed_response
        data = {
          content: feed_response.body,
          content_type: feed_response.headers['Content-Type'],
          timestamp: Time.now.to_i,
        }
        RSSCache.instance.store(url, data)
      end
    end
    response.headers['Content-Type'] = data[:content_type]
    render text: data[:content]
  end
end
