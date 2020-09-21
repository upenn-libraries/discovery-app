# This module overrides Blacklight's mail-sending methods to only
# actually send an email if there are documents selected.
# MK 9/2020 - Why? Dunno. Maybe crawlers hit the urls and this was throwing
# exceptions?
module HandleEmptyEmail

  extend ActiveSupport::Concern

  # override of method in Blacklight::Catalog
  def email_action(documents)
    return unless documents.any? && email_is_legit(params[:to])

    begin
      retries ||= 0
      super(documents)
    rescue Net::ReadTimeout => e
      sleep 3
      if (retries += 1) < 2
        retry
      else
        Honeybadger.notify e
      end
    end
  end

  # override of method in Blacklight::Catalog
  # Note: Penn seems to have disabled the links to send a SMS
  def sms_action(documents)
    return unless documents.any?

    super(documents)
  end

  # Check if email address matches RegEx
  # @param [String] email
  # @return [Fixnum, nil]
  def email_is_legit(email)
    email =~ URI::MailTo::EMAIL_REGEXP
  end
end
