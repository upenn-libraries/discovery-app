require 'httpclient'

class BentoSearch::ColendaEngine

  include BentoSearch::SearchEngine

  def search_implementation(args)
    return if args[:query].nil?

    query = args[:query]
    url = colenda_url query
    http_client = HTTPClient.new
    results = BentoSearch::Results.new
    hash, response, exception = nil

    begin
      response = http_client.get(url, nil, nil)
      hash = JSON.parse(response.body)
    rescue BentoSearch::RubyTimeoutClass, HTTPClient::ConfigurationError, HTTPClient::BadResponseError, MultiJson::DecodeError, Nokogiri::SyntaxError => e
      exception = e
    end

    if (response.nil? || hash.nil? || exception ||
        (! HTTP::Status.successful? response.status))
      results.error ||= {}
      results.error[:exception] = e
      results.error[:status] = response.status if response.present?
      return results
    end

    results.total_items = hash['response']['pages']['total_count'].to_i
    return results unless results.total_items.positive?

    entries = hash['response']['docs']
    entries.each do |entry|
      item = BentoSearch::ResultItem.new
      item.title = entry['title_ssim'].first
      item.link = colenda_item_url(entry['id'])
      item.custom_data['thumbnail'] = entry['thumbnail_url']
      results << item
    end
    results
  end

  def colenda_item_url(id)
    "https://colenda.library.upenn.edu/catalog/#{id}"
  end

  def colenda_url(query)
    "https://colenda.library.upenn.edu/catalog.json?per_page=5&q=#{CGI.escape(query)}"
  end


end
