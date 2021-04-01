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
                # TODO: get OpenURL from Alma GES?
                # ill_url = get_ill_openurl_from_alma params[:mms_id], params[:holding_id], params[:item_id] ??
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

  def ill_openurl_from_alma(mms_id, holding_id, item_id)

  end
end
