# frozen_string_literal: true

# Requesting actions
class RequestsController < ApplicationController
  before_action :set_item, only: :submit

  def confirm
    partial = partial_for_request_type params
    set_ill_url if partial == 'ill'
    render "requests/confirm/#{partial}", layout: false
  end

  def submit
    request = build_request @item, params
    @response = RequestSubmissionService.submit request
    render 'requests/done', layout: false
  end

  private

  def set_item
    @item = TurboAlmaApi::Client.item_for mms_id: params[:mms_id].to_s,
                                          holding_id: params[:holding_id].to_s,
                                          item_pid: params[:item_pid].to_s
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
    options = TurboAlmaApi::Client.request_options mms_id, user_id
    options.dig('ILLIAD') || ill_request_form_url_for(mms_id)
  end

  # @param [TurboAlmaApi::Bib::PennItem] item
  # @param [ActionController::Parameters] params
  # @return [TurboAlmaApi::Request, Illiad::Request]
  def build_request(item, params)
    if params[:delivery].in? %w[mail scandeliver]
      Illiad::Request.new user_id, user_email, item, params
    elsif params[:delivery].in? %w[pickup]
      TurboAlmaApi::Request.new user_id, user_email, item, params
    end
  end

  # because current_user is useless
  # @return [String]
  def user_id
    session['id']
  end

  # @return [String]
  def user_email
    session['email']
  end
end
