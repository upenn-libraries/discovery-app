# frozen_string_literal: true

# Send requests to a service
# TODO: confirmation emails?
class RequestSubmissionService
  class RequestFailed < StandardError; end

  # @param [TurboAlmaApi::Request] request
  def self.submit(request)
    response = submission_response_for request
    { status: :success,
      message: "Submission successful. Confirmation number is #{response}" }
  rescue StandardError => e
    { status: :failure, message: e.message }
  end

  # @param [TurboAlmaApi::Request] request
  def self.submission_response_for(request)
    case request.target_system
    when :alma
      # alma_request request
    when :illiad
      # illiad_transaction request
    else
      raise ArgumentError,
            "Unsupported submission target system: #{request.target_system}"
    end
  end

  # @param [TurboAlmaApi::Request] request
  # @param [Object] alma_user
  # @param [IlliadApiClient] api
  # def self.illiad_transaction(request, api = IlliadApiClient.new)
  #   recipient_user = request.recipient_user || request.user
  #   api.get_or_create_illiad_user recipient_user
  #   data = illiad_transaction_data_from request
  #   api.transaction data
  # rescue StandardError => e
  #   raise RequestFailed, e.message
  # end

  # @param [TurboAlmaApi::Request] request
  # @param [AlmaApiClient] api
  # def self.alma_request(request, api = AlmaApiClient.new)
  #   api.create_item_request request
  # rescue StandardError => e
  #   raise RequestFailed => e.message
  # end

  # @param [TurboAlmaApi::Request] request
  # @return [Hash] data for Alma API
  def self.illiad_transaction_data_from(request)
    # request.for_illiad
  end
end
