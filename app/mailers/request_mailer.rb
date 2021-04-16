# frozen_string_literal: true

# Mail actions for Requests
class RequestMailer < ApplicationMailer
  # @param [Hash] info
  # @param [String] to recipient
  def confirmation_email(info, to)
    @info = info
    mail(to: to, subject: 'Franklin Request confirmation')
  end
end
