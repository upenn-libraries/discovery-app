# frozen_string_literal: true

class RequestsController < ApplicationController
  def confirm

    partial = case params[:method].to_sym
              when :sad then 'sad'
              when :pap then 'pap'
              when :bbm then 'bbm'
              else
                # TODO: error
              end

    render "requests/confirm/#{partial}", layout: false
  end

  def submit; end
end
