# frozen_string_literal: true

# Requesting actions
class RequestsController < ApplicationController
  def confirm
    partial = case params[:type].to_sym
              when :circulate
                params[:available] ? 'circulate' : 'ill'
              when :electronic
                'electronic'
              when :ill
                @ill_url = ill_openurl_from_alma params[:mms_id]
                'ill'
              when :aeon
                'aeon'
              else
                # TODO: error
              end

    render "requests/confirm/#{partial}", layout: false
  end

  def submit; end

  private

  def ill_openurl_from_alma(mms_id)
    options = TurboAlmaApi::Client.request_options mms_id, current_user
    options.dig('ILLIAD') || ill_request_form_url_for(mms_id)
  end
end
