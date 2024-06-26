# frozen_string_literal: true

# abstract Request, wrapping creation and submission of either a:
# TurboAlmaApi::Request or a Illiad::Request
class AbstractRequest
  ILLIAD_DELIVERY_OPTIONS = [
    Illiad::Request::MAIL_DELIVERY,
    Illiad::Request::ELECTRONIC_DELIVERY,
    Illiad::Request::OFFICE_DELIVERY
  ]
  ALMA_FULFILLMENT_OPTIONS = %w[pickup].freeze

  class RequestFailed < StandardError; end

  # @param [TurboAlmaApi::Bib::PennItem, NilClass] item
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
    return response if response[:status] == :failed

    if @request.email
      send_confirmation_email response
    else
      Honeybadger.notify "User with no email address submitting a request: #{@request&.user_id}"
    end
    { status: :success,
      confirmation_number: response[:confirmation_number],
      title: response[:title] }
  rescue RequestFailed => e
    Honeybadger.notify e
    { status: :failed, message: I18n.t('requests.messages.request_failed') }
  end

  # Do the request using the proper API client
  # @return [Hash] response hash
  def perform_request
    if alma_fulfillment?
      @request = TurboAlmaApi::Request.new @user, @item, @params
      TurboAlmaApi::Client.submit_request @request
    elsif illiad_fulfillment?
      @request = Illiad::Request.new @user, @item, @params
      illiad_api.get_or_create_illiad_user @request.user_id
      transaction_response = illiad_api.transaction @request.to_h
      confirmation_number = transaction_response[:confirmation_number]
      # add notes
      if confirmation_number
        if @request.note.present?
          illiad_api.add_note confirmation_number, @request.note, @request.user_id
        end
        if @request.delivery == Illiad::Request::MAIL_DELIVERY && @user[:group] == 'Faculty Express'
          illiad_api.add_note(
            confirmation_number,
            'Delivery Choice: Faculty Express patron requests BBM/UPS delivery for this loan'
          )
        end
      end
      transaction_response
    else
      Honeybadger.notify "Problem handling request submission! Params: #{@params}"
      raise ArgumentError, I18n.t('requests.messages.alma_response.other')
    end
  rescue StandardError => e
    raise RequestFailed, e.message
  end

  private

  # @param [Hash] response
  def send_confirmation_email(response)
    RequestMailer.confirmation_email(response, @request)
                 .deliver_now
  end

  # @return [TrueClass, FalseClass]
  def alma_fulfillment?
    @params[:delivery].in? ALMA_FULFILLMENT_OPTIONS
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
