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
    NOTE_TYPE = 'Staff'.freeze # TODO: get Atlas to allow creation of user notes via API

    base_uri ENV.fetch('ILLIAD_API_BASE_URI')

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
      raise RequestFailed, "Problem building user from Illiad: #{e.message}"
    end

    # Sufficient mapped data to create an ILLiad user
    # @param [String] username
    def illiad_data_for(username)
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
        'Address' => '', # TODO: get it from alma_user preferred address?
        # from here on, just setting things that we've normally set. many of these could be frivolous
        'DeliveryMethod' => 'Mail to Address',
        'Cleared' => 'Yes',
        'Web' => true, # TODO: question this?
        'ArticleBillingCategory' => 'Exempt',
        'LoanBillingCategory' => 'Exempt'
      }
    end

    # @param [String] username
    # @return [Array, NilClass]
    def address_info_for(username)
      user_info = get_user username
      return nil unless user_info

      [user_info['Address'], user_info['Address2']]
    end

    # @param [String] comment
    # @param [String] transaction_number form Illiad response when creating transaction
    def add_note(transaction_number, comment, user_id)
      unless transaction_number
        Honeybadger.notify 'add_note called with no transaction_number!'
        return
      end

      # TODO: ugly
      proper_transaction_number = transaction_number.sub /^ILLIAD/, ''
      comment_with_user = comment + " - comment submitted by #{user_id}"
      options = @default_options
      options[:body] = {
        'NoteType' => NOTE_TYPE,
        'Note' => comment_with_user
      }
      note_url = "/transaction/#{proper_transaction_number}/notes"
      respond_to self.class.post(note_url, options)
    end
    
    private

    def respond_to(response, exception_class = RequestFailed)
      raise(exception_class, response.body) unless response.success?

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
