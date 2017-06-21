# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store, key: '_blacklight_session'

# monkey patch Session to fix issue with #keys and #values not returning data in rails 4.2.x
# my PR fixing this bug was accepted but it won't be backported to 4.2.x
# https://github.com/rails/rails/pull/28895
# TODO: remove this when we upgrade to rails >= 5.1.2? I think?

class ActionDispatch::Request::Session

  alias_method :orig_keys, :keys
  alias_method :orig_values, :values

  def keys
    load_for_read!
    orig_keys
  end

  def values
    load_for_read!
    orig_values
  end
end
