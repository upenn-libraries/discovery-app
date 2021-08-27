# frozen_string_literal: true

module TurboAlmaApi
  module Bib
    # Represent a set of Items built from API response
    class PennItemSet
      extend ::Forwardable

      # minimize API requests overall for now, but a lower number may give
      # better overall performance?
      ITEMS_PER_REQUEST = 100

      attr_accessor :mms_id, :alma_username, :total_count

      def_delegators :@items, :each, :length, :[], :first, :sort_by

      # @param [String] mms_id
      # @param [Hash] options
      # @option [String] username
      # @option [Integer] item_count
      # @option [Integer] empty_holding_count
      def initialize(mms_id, options = {})
        @mms_id = mms_id
        @alma_username = options.dig :username
        @item_count = options.dig(:item_count)&.to_i # item_count from params
        if @item_count && @item_count > 1
          @total_count = @item_count
          @items = bulk_retrieve_items
        else
          first_items_response = TurboAlmaApi::Client.api_get_request(
            items_url(username: options.dig(:username), limit: 1)
          )
          parsed_response = Oj.load first_items_response.body
          @total_count = parsed_response['total_record_count'].to_i
          @items = if @total_count == 1
                     Array.wrap PennItem.new parsed_response['item'].first
                   elsif @total_count > 1
                     bulk_retrieve_items
                   else
                     []
                   end
        end
        # add items representing empty holdings if needed
        if options[:empty_holding_count].to_i > 0
          holdings = TurboAlmaApi::Client.all_holdings_for @mms_id
          items_and_empty_holdings holdings
        else
          @items
        end
      end

      # iterate through holdings, skip if corresponding item found (with holding_id)
      # for the remainder, add an pseudo-item???
      # @param [Hash] holdings
      def items_and_empty_holdings(holdings)
        item_holding_ids = @items.collect(&:holding_id).uniq
        holdings['holding'].each do |holding|
          next if holding['holding_id'].in? item_holding_ids

          @items << TurboAlmaApi::Bib::PennItem.new(
            # fake an item, ugh
            { 'holding_data' => holding,
              'bib_data' => holdings['bib_data'],
              'item_data' => {} }
          )
        end
        @items
      end

      def to_json(_options = {})
        Oj.dump @items&.map(&:for_select)
      end

      private

      # @return [Array<Alma::BibItem>]
      def bulk_retrieve_items
        requests_needed = (@total_count / ITEMS_PER_REQUEST) + 1
        hydra = Typhoeus::Hydra.hydra
        requests = (1..requests_needed).map do |request_number|
          request_url = items_url limit: ITEMS_PER_REQUEST,
                                  offset: offset_for(request_number),
                                  username: @alma_username
          request = Typhoeus::Request.new request_url,
                                          headers: TurboAlmaApi::Client::DEFAULT_REQUEST_HEADERS
          hydra.queue request
          request
        end
        hydra.run # runs all requests in parallel
        returned_items = requests.map do |request|
          return nil unless request.response.success?

          parsed_response = Oj.load request.response.body
          parsed_response['item']&.map do |item_data|
            TurboAlmaApi::Bib::PennItem.new item_data
          end
        end.compact.flatten
        returned_items.reject &:hide_from_patrons?
      end

      # @param [Fixnum] request_number
      # @return [Fixnum]
      def offset_for(request_number)
        return 0 if request_number == 1

        (ITEMS_PER_REQUEST * (request_number - 1)) + 1
      end

      # @param [Hash] options
      # @return [String (frozen)]
      def items_url(options = {})
        minimal_url = "#{TurboAlmaApi::Client::BASE_URL}/v1/bibs/#{@mms_id}/holdings/ALL/items?expand=due_date,due_date_policy&order_by=description&direction=asc"
        minimal_url += "&user_id=#{options[:username]}" if options[:username].present?
        minimal_url += "&offset=#{options[:offset]}" if options[:offset].present?
        minimal_url += "&limit=#{options[:limit]}" if options[:limit].present?
        minimal_url
      end
    end
  end
end
