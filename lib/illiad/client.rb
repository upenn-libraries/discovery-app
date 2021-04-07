# frozen_string_literal: true

module Illiad
  # ILLiad API client
  class Api
    include HTTParty

    class UserNotFound < StandardError; end
    class RequestFailed < StandardError; end
    class InvalidRequest < StandardError; end

    # Illiad API documentation states that _only_ Username is required. User create
    # requests fail, though, with an empty 400 response if NVTGC is not also specified.
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
    # @return [String, nil]
    # @raise RequestFailed
    def transaction(transaction_data)
      options = @default_options
      options[:body] = transaction_data
      response = self.class.post('/transaction', options)
      parsed_response = JSON.parse response.body
      unless parsed_response.key? 'TransactionNumber'
        raise RequestFailed, "Illiad transaction submission failed: #{response.message}"
      end

      parsed_response['TransactionNumber']
    end

    # Get user info from Illiad
    # @param [String] username
    # @return [Hash, nil] parsed response
    def get_user(username)
      respond_to self.class.get("/users/#{username}", @default_options), UserNotFound
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

    # @param [AlmaUser] alma_user
    def get_or_create_illiad_user(alma_user)
      _user = get_user alma_user.pennkey
    rescue UserNotFound => _e
      create_user illiad_data_from alma_user
    end

    # Sufficient mapped data to create an ILLiad user
    # @param [AlmaUser] alma_user
    def illiad_data_from(alma_user)
      {
        'Username' => alma_user.pennkey,
        'LastName' => alma_user.last_name,
        'FirstName' => alma_user.first_name,
        'EMailAddress' => alma_user.email,
        'NVTGC' => 'VPL',
        'Status' => alma_user.user_group,
        'Department' => alma_user.affiliation,
        'PlainTextPassword' => Illiad::DEFAULT_PASSWORD,
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

      JSON.parse(response.body).transform_keys { |k| k.downcase.to_sym }
    end

    # Checks if user_info includes minimum required Illiad API fields
    # @param [Hash] user_info
    # @return [TrueClass, FalseClass]
    def required_user_fields?(user_info = {})
      (CREATE_USER_REQUIRED_FIELDS - user_info.keys).empty?
    end

    def headers
      { 'ApiKey' => ENV['ILLIAD_API_KEY'],
        'Accept' => 'application/json; version=1' }
    end
  end
end