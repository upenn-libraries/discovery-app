# This module overrides Blacklight's mail-sending methods to only
# actually send an email if there are documents selected.
# MK 9/2020 - Why? Dunno. Maybe crawlers hit the urls and this was throwing
# exceptions?
module EmailActionProtection

  extend ActiveSupport::Concern

  # override of method in Blacklight::Catalog
  def email_action(documents)
    return unless documents.any? && email_is_legit(params[:to])

    # only proceed if user is logged in
    return unless current_user

    begin
      retries ||= 0
      super(documents)
    rescue Net::ReadTimeout => e
      sleep 3
      raise e if (retries += 1) > 2

      retry
    end
  end

  # override of method in Blacklight::Catalog
  # Note: Penn seems to have disabled the links to send a SMS
  def sms_action(documents)
    return unless documents.any?

    super(documents)
  end

  # Check if email address matches RegEx
  # TODO: BL may already do this: see validate_email_params
  # @param [String] email
  # @return [Fixnum, nil]
  def email_is_legit(email)
    email =~ URI::MailTo::EMAIL_REGEXP
  end
end
