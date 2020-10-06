require 'httpclient'
require 'oga'

require 'net/http'
require 'json'

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

      mms_id = entry['id'].split('/').last.gsub('FRANKLIN_','')

      holdings_url = holdings_url(mms_id)

      holdings_response = http_client.get(holdings_url, nil, nil)

      holdings = JSON.parse(holdings_response.body)

      # TODO: Get a hidden reference to this value into the atom payload so it is referencable from the summary variable
      parsed_summary = Oga.parse_html(entry['summary'])
      link = parsed_summary.at_xpath('//a')
      if link
        # If a link exists, we are not opinionated about what it must be. e.g., if href.nil? || href=='', we just pass
        # it along. The exception is that we generate placeholder link text if none is present, to ensure that any
        # links generated downstream will be visible/clickable.
        href = link.attribute('href').to_s
        online_resource[href] = link.text.strip.presence || '[no link text]'
      end

      holdings_string = mms_id.downcase.start_with?("hathi") ? '' : determine_holdings_status(holdings, mms_id, online_resource)

      item.authors = entry['author'].present? ? [BentoSearch::Author.new(:display => entry['author'].first[1])] : []

      summary = Hash.from_xml(Nokogiri::XML(entry['summary']).to_xml)

      if summary.nil? || !summary['dl']
        list_terms = []
        list_definitions = [];
      else
        list_terms = summary['dl']['dt'].respond_to?(:each) ? summary['dl']['dt'] : [summary['dl']['dt']]
        list_definitions = summary['dl']['dd'].respond_to?(:each) ? summary['dl']['dd'] : [summary['dl']['dd']]
      end
      
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

      item.custom_data['holdings'] = holdings_string

      results << item

    end

    return results

  end

  def determine_holdings_status(holdings, mms_id, online_resource)
    holdings_string, holdings_type = ''
    holdings_type = "online" if holdings.dig("availability",mms_id, "holdings",0, "inventory_type") == "electronic"
    holdings_type = "print" if holdings.dig("availability",mms_id, "holdings",0, "inventory_type") == "physical"

    holdings_length = holdings.dig("availability",mms_id, "holdings")&.length || 0
    # TODO: this could be misleading - "check holdings" might still include a legit holding
    number_of_print = holdings.dig("availability",mms_id,"holdings")&.select { |p| p['availability'] == 'available' }&.length || 0
    number_of_online = holdings.dig("availability",mms_id,"holdings")&.select { |p| p['activation_status']&.downcase == 'available' } &.length || 0

    holdings_string = "See request options" if ((holdings_length == 0) || (number_of_print == 0 && number_of_online == 0)) && online_resource.empty?
    holdings_string = "#{number_of_print} #{holdings_type} #{"option".pluralize(number_of_print)}" if number_of_print > 1
    holdings_string = "Available - #{holdings.dig("availability",mms_id,"holdings",0,"library")} #{holdings.dig("availability",mms_id,"holdings",0,"call_number")}" if number_of_print == 1
    holdings_string = "#{number_of_online} #{holdings_type} #{"option".pluralize(number_of_online)}" if number_of_online > 0 && online_resource.empty?

    return holdings_string
  end

  def catalog_url(args)
    facet_args = ''
    return "https://franklin.library.upenn.edu/catalog.atom?per_page=5&q=#{CGI.escape(args[:query_term])}&search_field=#{CGI.escape(args[:field_term])}&f#{CGI.escape("[#{args[:f_term]}][]")+"="+CGI.escape(args[:f_value])}"
  end

  def holdings_url(mms_id)
    return "https://franklin.library.upenn.edu/alma/availability.json?id_list=#{mms_id}"
  end

  def public_settable_search_args
    super + [:f_term, :f_value]
  end
end
