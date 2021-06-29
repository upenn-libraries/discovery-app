# frozen_string_literal: true

module Illiad
  # ILLiad API client
  class ApiClient
    include HTTParty

    class RequestFailed < StandardError; end
    class InvalidRequest < StandardError; end

    # Illiad API documentation states that _only_ Username is required. User
    # create requests fail, though, with an empty 400 response if NVTGC is
    # not also specified.
    CREATE_USER_REQUIRED_FIELDS = %w[Username NVTGC].freeze

    base_uri ENV['ILLIAD_API_BASE_URI']

    def initialize
      @default_options = { headers: headers }
    end

    def version
      self.class.get '/SystemInfo/APIVersion'
    end

    def secure_version
      self.class.get '/SystemInfo/SecurePlatformVersion', @default_options
    end

    # Submit a transaction request and return transaction number if successful
    # @param [Hash] transaction_data
    # @return [Hash]
    # @raise RequestFailed
    def transaction(transaction_data)
      options = @default_options
      options[:body] = transaction_data
      response = self.class.post('/transaction', options)
      parsed_response = Oj.load response.body
      unless parsed_response.key? 'TransactionNumber'
        raise RequestFailed, "Illiad transaction submission failed: #{response.message}"
      end

      { title:
          (transaction_data[:LoanTitle] || transaction_data[:PhotoJournalTitle]),
        confirmation_number:
          parsed_response['TransactionNumber'].to_s.prepend('ILLIAD') }
    end

    # Get user info from Illiad
    # @param [String] username
    # @return [Hash, nil] parsed response
    def get_user(username)
      user_response = self.class.get("/users/#{username}", @default_options)
      return Oj.load(user_response.body) if user_response.code == 200

      nil
    end

    # Create an Illiad user with a username, at least
    # @param [Hash] user_info
    # @return [Hash, nil]
    def create_user(user_info)
      options = @default_options
      raise InvalidRequest unless required_user_fields? user_info

      options[:body] = user_info
      respond_to self.class.post('/users', options)
    end

    # @param [String] username
    def get_or_create_illiad_user(username)
      user = get_user username
      return user if user.present?

      create_user illiad_data_for username
    rescue StandardError => e
      raise RequestFailed, e.message
    end

    # Sufficient mapped data to create an ILLiad user
    # @param [String] username
    def illiad_data_for(username)
      # TODO: how to grab these attributes? for a logged-in user (via SSO)
      #       some of these attributes will be in the session. others will require
      #       calling back to the Alma User API....or....?
      #       Just call the user API for now...
      #       I could save all the required values from below to the session?
      alma_user = TurboAlmaApi::User.new username
      {
        'Username' => username,
        'LastName' => alma_user.last_name,
        'FirstName' => alma_user.first_name,
        'EMailAddress' => alma_user.email,
        'NVTGC' => 'VPL',
        'Status' => alma_user.user_group,
        'Department' => alma_user.affiliation,
        'PlainTextPassword' => ENV['ILLIAD_USER_PASSWORD'],
        'Address' => '', # TODO: get it from alma_user preferred address
        # from here on, just setting things that we've normally set. many of these could be frivolous
        'DeliveryMethod' => 'Mail to Address',
        'Cleared' => 'Yes',
        'Web' => true, # TODO: question this
        'ArticleBillingCategory' => 'Exempt',
        'LoanBillingCategory' => 'Exempt'
      }
    end

    private

    def respond_to(response, exception_class = RequestFailed)
      raise(exception_class, response.body) unless response.code == 200

      Oj.load(response.body).transform_keys { |k| k.downcase.to_sym }
    end

    # Checks if user_info includes minimum required Illiad API fields
    # @param [Hash] user_info
    # @return [TrueClass, FalseClass]
    def required_user_fields?(user_info = {})
      (CREATE_USER_REQUIRED_FIELDS - user_info.keys).empty?
    end

    def headers
      { 'ApiKey' => ENV.fetch('ILLIAD_API_KEY'),
        'Accept' => 'application/json; version=1' }
    end
  end
end
