
class RSSCache < Hash
  include Singleton
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
    if uri.instance_of? URI::HTTPS
      http.use_ssl = true
    end
    response = http.request(req)

    if response.header['location']
      newurl = URI.parse(response.header['location'])
      if(newurl.relative?)
        newurl = url + response.header['location']
      end
      make_request(newurl.to_s, limit + 1)
    else
      response
    end
  end

  def rss_proxy(url, lifetime = 900)
    struct = RSSCache.instance[url]
    if !struct || (Time.now.to_i > struct[:timestamp] + lifetime)
      begin
        feed_response = make_request(url)
      rescue
        Rails.logger.warn("rss_proxy: error fetching URL: #{url}")
      end
      if feed_response
        struct = {
          content: feed_response.body,
          content_type: feed_response['Content-Type'],
          timestamp: Time.now.to_i,
        }
        RSSCache.instance[url] = struct
      end
    end
    response.headers['Content-Type'] = struct[:content_type]
    render text: struct[:content]
  end

end