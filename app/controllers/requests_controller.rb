# frozen_string_literal: true

# Requesting actions
class RequestsController < ApplicationController
  def confirm
    partial = partial_for_request_type params
    set_ill_url if partial == 'ill'
    render "requests/confirm/#{partial}", layout: false
  end

  def submit
    item = TurboAlmaApi::Client.item_for mms_id: params[:mms_id].to_s,
                                         holding_id: params[:holding_id].to_s,
                                         item_pid: params[:item_pid].to_s
    request = TurboAlmaApi::Request.new current_user, item, params
    @response = RequestSubmissionService.submit request
    render 'requests/done', layout: false
  end

  private

  # Set the ILL URL for use in the ILL confirmation partial
  # @return [String]
  def set_ill_url
    @ill_url = ill_openurl_from_alma params[:mms_id].to_s
  end

  # Determine partial for modal dialogue based on request params
  # @param [ActionController::Parameters] params
  def partial_for_request_type(params)
    case params[:type].to_sym
    when :circulate
      params[:available] ? 'circulate' : 'ill'
    when :ill then 'ill'
    when :electronic then 'electronic'
    when :aeon then 'aeon'
    else
      # TODO: better error
      raise ArgumentError, 'Could not determine a request type for confirmation'
    end
  end

  # Get ILL URL from Alma API client
  # @param [String] mms_id
  def ill_openurl_from_alma(mms_id)
    options = TurboAlmaApi::Client.request_options mms_id, current_user
    options.dig('ILLIAD') || ill_request_form_url_for(mms_id)
  end
end
