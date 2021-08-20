# frozen_string_literal: true

module TurboAlmaApi
  # support "Request form Penn Libraries" functionality
  class Client
    BASE_URL = 'https://api-na.hosted.exlibrisgroup.com/almaws'
    DEFAULT_REQUEST_HEADERS =
      { "Authorization": "apikey #{ENV['ALMA_API_KEY']}",
        "Accept": 'application/json',
        "Content-Type": 'application/json' }.freeze

    class ItemNotFound < StandardError; end
    class RequestFailed < StandardError; end
    class Timeout < StandardError; end

    # Get all Items from the Alma API for a record without waiting too much
    # @return [TurboAlmaApi::Bib::ItemSet]
    # @param [String] mms_id
    # @param [Hash] options
    # @option [String] username
    # @option [Integer] item_count
    # @option [Integer] empty_holding_count
    def self.all_items_for(mms_id, options = {})
      Bib::PennItemSet.new mms_id, options
    end

    # @param [String] mms_id
    # @return [Hash]
    def self.all_holdings_for(mms_id)
      response = api_get_request "#{BASE_URL}/v1/bibs/#{mms_id}/holdings"
      Oj.load response.body
    end

    # Get a single Item
    # @return [TurboAlmaApi::Bib::PennItem]
    # @param [String] mms_id
    # @param [String] holding_id
    # @param [String] item_pid
    def self.item_for(mms_id:, holding_id:, item_pid:)
      unless mms_id && holding_id && item_pid
        raise ArgumentError, 'Insufficient identifiers set'
      end

      item_url = "#{BASE_URL}/v1/bibs/#{mms_id}/holdings/#{holding_id}/items/#{item_pid}"
      response = api_get_request item_url
      parsed_response = Oj.load response.body
      raise ItemNotFound, "Item can't be found for: #{item_pid}" if parsed_response['errorsExist']

      TurboAlmaApi::Bib::PennItem.new parsed_response
    end

    # see: https://developers.exlibrisgroup.com/alma/apis/docs/bibs/UE9TVCAvYWxtYXdzL3YxL2JpYnMve21tc19pZH0vcmVxdWVzdHM=/
    def self.submit_title_request(request); end

    # @param [PennItem] item
    # @param [Hash] user
    # @param [Hash] params
    def self.item_request(item, user, params)
      request = TurboAlmaApi::Request.new user, item, params
      submit_request request
    end

    # Submits a HOLD request to Alma
    # -Request- object must respond to:
    #  * pickup location
    #  * comments
    #  * mms_id, holding_id, item_pid
    # @param [Request] request
    def self.submit_request(request)
      query = { user_id: request.user_id, user_id_type: 'all_unique' }
      body = { 'request_type' => 'HOLD', 'pickup_location_type' => 'LIBRARY',
               'pickup_location_library' => request.pickup_location,
               'comment' => request.comments }
      request_url = "#{BASE_URL}/v1/bibs/#{request.mms_id}/holdings/#{request.holding_id}/items/#{request.item_pid}/requests"

      response = Typhoeus.post request_url,
                               headers: DEFAULT_REQUEST_HEADERS,
                               params: query,
                               body: Oj.dump(body)
      parsed_response = Oj.load response.body

      raise RequestFailed, "Unparseable response from Alma for Request URL: #{request_url}" unless parsed_response

      if parsed_response.key?('web_service_response') || parsed_response.key?('errorsExist')
        first_error_message = parsed_response['errorList']['error'].first['errorMessage']
        raise RequestFailed, first_error_message # TODO: better error message details
        # boo, get error code
        # 401890 User with identifier X of type Y was not found.
        # 401129 No items can fulfill the submitted request.
        # 401136 Failed to save the request: Patron has active request for selected item.
        # 60308 Delivery to personal address is not supported.
        # 60309 User does not have address for personal delivery.
        # 60310 Delivery is not supported for this type of personal address.
        # 401684 Search for request physical item failed.
        # 60328 Item for request was not found.
        # 60331 Failed to create request.
        # 401652 General Error - An error has occurred while processing the request.
      else
        # TODO: get confirmation code/request id
        { title: parsed_response['title'],
          confirmation_number: parsed_response['request_id'].prepend('ALMA') }
      end
    end

    # get title-level request options
    # @param [String] mms_id
    def self.request_options(mms_id, user_id = 'GUEST')
      request_url = "#{BASE_URL}/v1/bibs/#{mms_id}/request-options?user_id=#{user_id}"
      response = api_get_request request_url
      parsed_response = Oj.load response.body
      options = {}
      raise RequestFailed, "Problem getting request options for MMS ID: #{mms_id}" if parsed_response.dig 'web_service_result', 'errorsExist'

      parsed_response['request_option']&.each do |option|
        option_name = if option.key? 'general_electronic_service_details'
                        option.dig 'general_electronic_service_details', 'code'
                      elsif option.key? 'rs_broker_details'
                        option.dig 'rs_broker_details', 'code'
                      else
                        option.dig 'type', 'value'
                      end
        options[option_name] = option.dig 'request_url'
      end
      options
    end

    # Perform a get request with the usual Alma API request headers
    # @param [String] url
    # @param [Hash] headers
    def self.api_get_request(url, headers = {})
      headers.merge! DEFAULT_REQUEST_HEADERS
      Typhoeus.get url, headers: headers
    end
  end
end
