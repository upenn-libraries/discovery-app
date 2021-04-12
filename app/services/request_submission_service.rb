# frozen_string_literal: true

# Send requests to a service
# TODO: confirmation emails?
class RequestSubmissionService
  class RequestFailed < StandardError; end

  # @param [TurboAlmaApi::Request, Illiad::Request] request
  def self.submit(request)
    if Rails.env.development?
      response = submission_response_for request
      { status: :success,
        message: "Submission successful. Confirmation number is #{response}" }
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
    recipient_username = request.recipient_username || request.username
    api.get_or_create_illiad_user recipient_username
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
