require 'httpclient'
require 'oga'

class BentoSearch::ColendaEngine

  include BentoSearch::SearchEngine

  def search_implementation(args)
    return if args[:query].nil?
    terms = { :query_term => args[:query],
              :field_term => 'keyword',
              :f_term => args[:f_term].present? ? args[:f_term] : '',
              :f_value => args[:f_value].present? ? args[:f_value] : ''

    }

    url = colenda_url(terms)

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
    return results unless results.total_items > 0

    entries = hash['response']['docs']

    entries.each do |entry|
      online_resource = {}
      item = BentoSearch::ResultItem.new
      item.title = entry['title_ssim'].first
      item.link = colenda_item_url(entry['id'])
      item.authors = [entry['personal_name_sim'], entry['creator_sim'], entry['corporate_name_sim']].compact.flatten.join(', ')
      item.format = entry['format_ssim']&.join(', ')
      item.publisher = entry['publisher_ssim']&.join(', ')
      item.custom_data['thumbnail'] = entry['thumbnail_url']

      results << item

    end

    return results

  end

  def colenda_item_url(id)
    "https://colenda.library.upenn.edu/catalog/#{id}"
  end

  def colenda_url(args)
    "https://colenda.library.upenn.edu/catalog.json?per_page=5&q=#{CGI.escape(args[:query_term])}"
  end


end
