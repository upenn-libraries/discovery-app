require 'httpclient'
require 'oga'

class BentoSearch::DatabasesEngine

  include BentoSearch::SearchEngine

  def search_implementation(args)
    return if args[:query].nil?
    terms = { :query_term => args[:query],
              :field_term => 'keyword',
              :f_term => args[:f_term].present? ? args[:f_term] : '',
              :f_value => args[:f_value].present? ? args[:f_value] : ''

    }

    url = databases_url(terms)

    Rails.logger.debug("Databases URL: #{url}")

    http_client = HTTPClient.new

    results = BentoSearch::Results.new

    hash, response, exception = nil

    begin
      response = http_client.get(url, nil, nil)
      hash = Hash.from_xml( response.body )

    rescue BentoSearch::RubyTimeoutClass, HTTPClient::ConfigurationError, HTTPClient::BadResponseError, MultiJson::DecodeError, Nokogiri::SyntaxError => e
      exception = e
    end
    if (response.nil? || hash.nil? || exception ||
        (! HTTP::Status.successful? response.status))
      results.error ||= {}
      results.error[:exception] = e
      results.error[:status] = response.status if response

      return results
    end

    results.total_items = hash['feed']['totalResults'].to_i

    return results unless results.total_items > 0

    entries = results.total_items > 1 ? hash['feed']['entry'] : [hash['feed']['entry']]

    entries.each do |entry|
      online_resource = {}
      item = BentoSearch::ResultItem.new
      item.title = entry['title'].strip
      item.link = entry['id']

      # TODO: Get a hidden reference to this value into the atom payload so it is referencable from the summary variable
          if Oga.parse_html(entry['summary']).at_xpath('//a/@href').present?
            online_resource[Oga.parse_html(entry['summary']).at_xpath('//a/@href').text] = Oga.parse_html(entry['summary']).at_xpath('//a/text()').text.strip
          end

      summary = Hash.from_xml(entry['summary'])

      list_terms = summary['dl']['dt']
      list_definitions = summary['dl']['dd']

      list_terms.each_with_index do |term, index|
        case term.downcase[0..term.length-2]
        when 'publication'
          item.publisher = list_definitions[index]
        when 'format/description'
          item.format = list_definitions[index]
        when 'online resource'
          #TODO: Support multiple online resource links
          item.other_links = online_resource
        else
          item.custom_data[term] = list_definitions[index]
        end
      end

      results << item

    end

    return results

  end

  def databases_url(args)
    f_term = 'format_f'
    f_value = 'Database/Website'
    return "https://franklin.library.upenn.edu/catalog.atom?per_page=3&q=#{CGI.escape(args[:query_term])}&search_field=#{CGI.escape(args[:field_term])}&f#{CGI.escape("[#{f_term}][]")+"="+CGI.escape(f_value)}"
  end


end
