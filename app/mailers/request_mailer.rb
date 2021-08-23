# frozen_string_literal: true

# Mail actions for Requests
class RequestMailer < ApplicationMailer
  # @param [Hash] info
  # @param [TurboAlmaApi::Request, Illiad::Request] request
  def confirmation_email(info, request)
    @info = info
    @request = request
    mail(to: request.email, subject: I18n.t('requests.email.confirmation.subject'))
  end
end
