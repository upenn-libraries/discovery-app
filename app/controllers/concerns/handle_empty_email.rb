
module HandleEmptyEmail

  extend ActiveSupport::Concern

  # override
  def email_action(documents)
      super(documents) if documents.length > 0
  end

  # override
  def sms_action(documents)
      super(documents) if documents.length > 0
  end

end
