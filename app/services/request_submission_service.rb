# frozen_string_literal: true

# Send requests to a service
class RequestSubmissionService
  class RequestFailed < StandardError; end

  # @param [TurboAlmaApi::Request, Illiad::Request] request
  def self.submit(request)
    if Rails.env.development?
      response = submission_response_for request
      RequestMailer.confirmation_email(response, request.submitter_email)
                   .deliver_later
      { status: :success,
        confirmation_number: response[:confirmation_number],
        title: response[:title] }
    else
      { status: :success,
        message: 'Submission is disabled in this environment!' }
    end
  rescue StandardError => e
    { status: :failure, message: e.message }
  end

  # @param [TurboAlmaApi::Request, Illiad::Request] request
  def self.submission_response_for(request)
    case request
    when TurboAlmaApi::Request
      alma_request request
    when Illiad::Request
      illiad_transaction request
    else
      raise ArgumentError,
            "No configured submission logic for a #{request.class.name}"
    end
  end

  # @param [Illiad::Request] request
  # @param [Illiad::ApiClient] api
  def self.illiad_transaction(request, api = Illiad::ApiClient.new)
    api.get_or_create_illiad_user request.recipient_username
    data = illiad_transaction_data_from request
    api.transaction data
  rescue StandardError => e
    raise RequestFailed, e.message
  end

  # @param [TurboAlmaApi::Request] request
  # @param [TurboAlmaApi::Client] api
  def self.alma_request(request, api = TurboAlmaApi::Client)
    api.submit_request request
  rescue StandardError => e
    raise RequestFailed, e.message
  end

  # @param [Illiad::Request] request
  # @return [Hash] data for Illiad API
  def self.illiad_transaction_data_from(request)
    request.to_h
  end

end
