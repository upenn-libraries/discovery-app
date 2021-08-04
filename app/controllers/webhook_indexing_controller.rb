class WebhookIndexingController < ApplicationController
  before_action :validate
  def bib
    payload = JSON.parse request.body
    marcxml = payload.dig 'bib', 'anies'
    # TODO: respect "suppress_from_publishing"?
    case payload.dig 'event', 'value'
    when 'BIB_UPDATED'
      IndexUpdatedBibJob.perform_later marcxml
      head :ok
    when 'BIB_DELETED'
      IndexDeletedBibJob.perform_later marcxml
      head :ok
    when 'BIB_CREATED'
      IndexCreatedBibJob.perform_later marcxml
      head :ok
    else
      head :bad_request
    end
  end

  private

  # validate the signature header based on webhook secret and the request body content
  def validate
    hmac = OpenSSL::HMAC.new ENV['WEBHOOK_SECRET'], OpenSSL::Digest.new('sha256')
    hmac.update request.body
    if (request.env['X-Exl-Signature'] || request.env['HTTP_X_EXL_SIGNATURE']) == Base64.strict_encode64(hmac.digest)
      true
    else
      head :unauthorized
    end
  end
end
