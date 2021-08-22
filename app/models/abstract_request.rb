# frozen_string_literal: true

# abstract Request, wrapping creation and submission of either a:
# TurboAlmaApi::Request or a Illiad::Request
class AbstractRequest
  ILLIAD_DELIVERY_OPTIONS = [
    Illiad::Request::MAIL_DELIVERY,
    Illiad::Request::ELECTRONIC_DELIVERY,
    Illiad::Request::OFFICE_DELIVERY
  ]
  ALMA_DELIVERY_OPTIONS = %w[pickup].freeze

  class RequestFailed < StandardError; end

  # @param [TurboAlmaApi::Bib::PennItem] item
  # @param [Hash] user_data
  # @param [ActionController::Parameters] params
  def initialize(item, user_data, params = {})
    @item = item
    @user = user_data
    @params = params
  end

  # Handle submission of Request
  def submit
    response = perform_request
    RequestMailer.confirmation_email(response, @request)
                 .deliver_now
    { status: :success,
      confirmation_number: response[:confirmation_number],
      title: response[:title] }
  rescue RequestFailed => e
    Honeybadger.notify e
    { status: :failed, message: "Submission failed, please try again: #{e.message}" }
  end

  # Do the request using the proper API client
  # @return [Hash] response hash
  def perform_request
    if alma_fulfillment?
      @request = TurboAlmaApi::Request.new @user, @item, @params
      TurboAlmaApi::Client.submit_request @request
    elsif illiad_fulfillment?
      @request = Illiad::Request.new @user, @item, @params
      illiad_api.get_or_create_illiad_user @request.username
      illiad_api.transaction @request.to_h
    else
      raise ArgumentError,
            I18n.t('requests.messages.unsupported_submission_logic',
                   request_class: @request.class.name)
    end
  rescue StandardError => e
    raise RequestFailed, e.message
  end

  private

  # @return [TrueClass, FalseClass]
  def alma_fulfillment?
    @params[:delivery].in? ALMA_DELIVERY_OPTIONS
  end

  # @return [TrueClass, FalseClass]
  def illiad_fulfillment?
    @params[:delivery].in? ILLIAD_DELIVERY_OPTIONS
  end

  # @return [Illiad::ApiClient]
  def illiad_api
    @illiad_api ||= Illiad::ApiClient.new
  end
end
