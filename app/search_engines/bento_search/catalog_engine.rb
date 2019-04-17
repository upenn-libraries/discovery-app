require 'httpclient'
require 'oga'

class BentoSearch::CatalogEngine

  include BentoSearch::SearchEngine

  def search_implementation(args)
    return if args[:query].nil?
    terms = { :query_term => args[:query],
              :field_term => 'keyword',
              :f_term => args[:f_term].present? ? args[:f_term] : '',
              :f_value => args[:f_value].present? ? args[:f_value] : ''

    }

    url = catalog_url(terms)

    Rails.logger.debug("Catalog URL: #{url}")

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
      results.error[:status] = response.status if response.present?

      return results
    end

    results.total_items = hash['feed']['totalResults'].to_i

    return results unless results.total_items > 0

    entries = results.total_items > 1 ? hash['feed']['entry'] : [hash['feed']['entry']]

    entries.each do |entry|
      online_resource = {}
      item = BentoSearch::ResultItem.new
      item.title = entry['title'].strip.html_safe
      item.link = entry['id']

      item.authors = entry['author'].present? ? [BentoSearch::Author.new(:display => entry['author'].first[1])] : []

      # TODO: Get a hidden reference to this value into the atom payload so it is referencable from the summary variable
      if Oga.parse_html(entry['summary']).at_xpath('//a/@href').present?
        online_resource[Oga.parse_html(entry['summary']).at_xpath('//a/@href').text] = Oga.parse_html(entry['summary']).at_xpath('//a/text()').text.strip
      end

      summary = Hash.from_xml(Nokogiri::XML(entry['summary']).to_xml)

      list_terms = summary['dl']['dt'].respond_to?(:each) ? summary['dl']['dt'] : [summary['dl']['dt']]
      list_definitions = summary['dl']['dd'].respond_to?(:each) ? summary['dl']['dd'] : [summary['dl']['dd']]
      
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

  def catalog_url(args)
    facet_args = ''
    return "https://franklin.library.upenn.edu/catalog.atom?per_page=5&q=#{CGI.escape(args[:query_term])}&search_field=#{CGI.escape(args[:field_term])}&f#{CGI.escape("[#{args[:f_term]}][]")+"="+CGI.escape(args[:f_value])}"
  end

  def public_settable_search_args
    super + [:f_term, :f_value]
  end
end
