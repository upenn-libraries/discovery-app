# frozen_string_literal: true

# Requesting actions
class RequestsController < ApplicationController
  before_action :set_item, only: :submit

  def confirm
    partial = partial_for_request_type params
    set_ill_url if partial.in? %w[ill noncirc]
    set_address_info if user_alma_group == 'Faculty Express'
    render "requests/confirm/#{partial}", layout: false
  end

  def submit
    request = AbstractRequest.new @item, user_data, params
    @response = request.submit
    render 'requests/done', layout: false
  end

  def options
    options = TurboAlmaApi::Client.request_options(
      params[:mms_id].to_s, user_id
    )
    render json: options
  end

  private

  def set_item
    @item = if (params[:item_pid] == 'no-item') || params[:item_pid].blank?
              nil
            else
              TurboAlmaApi::Client.item_for mms_id: params[:mms_id].to_s,
                                            holding_id: params[:holding_id].to_s,
                                            item_pid: params[:item_pid].to_s
            end
  end

  def set_address_info
    @address_info = Illiad::ApiClient.new.address_info_for user_id
  end

  # Set the ILL URL for use in the ILL confirmation partial
  # @return [String]
  def set_ill_url
    @ill_url = ill_openurl_from_alma params[:mms_id].to_s
  end

  # Determine partial for modal dialog based on request params
  # @param [ActionController::Parameters] params
  def partial_for_request_type(params)
    case params[:type].to_sym
    when :circulate
      params[:available] ? 'circulate' : 'ill'
    when :noncirc then 'noncirc'
    when :ill then 'ill'
    when :electronic then 'electronic'
    when :aeon then 'aeon'
    else
      # TODO: better error
      raise ArgumentError, I18n.t('requests.messages.invalid_confirm_partial')
    end
  end

  # Get ILL URL from Alma API client
  # @param [String] mms_id
  def ill_openurl_from_alma(mms_id)
    options = TurboAlmaApi::Client.request_options mms_id, user_id
    options.dig('ILLIAD') || ill_request_form_url_for(mms_id)
  end

  # A backup in case we can't get the nice link from Alma
  # @param [String] mms_id
  def ill_request_form_url_for(mms_id)
    URI::HTTPS.build(host: request.host, path: '/redir/ill',
                     query: "bibid=#{mms_id}&rfr_id=info%3Asid%2Fprimo.exlibrisgroup.com").to_s
  end

  # because current_user is useless
  # @return [Hash{Symbol->String}]
  def user_data
    { id: user_id, email: user_email, group: user_alma_group }
  end

  # @return [String]
  def user_id
    session['id']
  end

  # Email might come from the session, or from a form submission
  # @return [String]
  def user_email
    session['email'] || params['email'].to_s
  end

  # @return [String]
  def user_alma_group
    session['user_group']
  end
end
