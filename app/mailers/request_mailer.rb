# frozen_string_literal: true

# Mail actions for Requests
class RequestMailer < ApplicationMailer
  # @param [Hash] info
  # @param [String] to recipient
  def confirmation_email(info, to)
    @info = info
    mail(to: to, subject: I18n.t('requests.email.confirmation.subject'))
  end
end
