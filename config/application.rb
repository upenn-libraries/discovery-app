require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Blacklight
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    config.eager_load_paths << Rails.root.join('lib')

    # TODO: fix the underlying problem, which is that CLIENT_IP doesn't match X_FORWARDED_FOR in headers
    # sent by Apache proxy. The only reason this is here is to allow some debugging code to iterate over
    # headers in request.headers without triggering an ActionDispatch::RemoteIp::IpSpoofAttackError exception
    config.action_dispatch.ip_spoofing_check = false

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: 'mailrelay.library.upenn.int'
    }
    config.action_mailer.default_options = { from: 'no-reply@upenn.edu' }

    config.log_level = ENV['RAILS_LOG_LEVEL'].present? ? ENV['RAILS_LOG_LEVEL'].to_sym : :debug
  end
end
