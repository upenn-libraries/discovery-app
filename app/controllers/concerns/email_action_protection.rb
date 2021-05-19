# frozen_string_literal: true

# This module overrides Blacklight's mail-sending methods to only
# actually send an email if there are documents selected and user
# is logged in
module EmailActionProtection
  extend ActiveSupport::Concern

  # override of method in Blacklight::Catalog
  def email_action(documents)
    super(documents) if documents_and_user_set
  end

  # override of method in Blacklight::Catalog
  # Note: Penn seems to have disabled the links to send a SMS
  def sms_action(documents)
    super(documents) if documents_and_user_set
  end

  # @return [TrueClass, FalseClass]
  def documents_and_user_set
    @documents.any? && current_user
  end
end
