source 'https://rubygems.org'

# TODO: audit this Gemfile

gem 'activerecord-jdbcmysql-adapter', '1.3.21', platforms: :jruby
gem 'bento_search', git: 'https://github.com/magibney/bento_search', branch: 'search_controller_engine_params' #'1.7' # TODO: switch back to official gem when PR #36 is accepted and makes it into a release
gem 'blacklight', '6.8.0', git: 'https://github.com/magibney/blacklight.git', branch: 'v6.8.0-solr7-qq-feedFormat'
gem 'blacklight-marc', '6.2.0'
gem 'blacklight-ris', git: 'https://github.com/upenn-libraries/blacklight-ris.git' # TODO: switch back to official gem when PR #21 is accepted and makes it into a release
gem 'blacklight_advanced_search', '6.3.1'
gem 'blacklight_alma', git: 'https://github.com/upenn-libraries/blacklight_alma.git'
gem 'blacklight_range_limit', '6.0.0'
gem 'blacklight_solrplugins', git: 'https://github.com/upenn-libraries/blacklight_solrplugins.git'
gem 'browserify-rails', '4.0.0'
gem 'coffee-rails', '4.2.1'
gem 'devise', '~> 4.6.0'
gem 'devise-guests', '0.5.0'
gem 'font-awesome-rails'
gem 'globalid', '0.3.7'
gem 'httparty'
gem 'jbuilder', '2.6.0'
gem 'jdbc-sqlite3', '3.8.11.2', platforms: :jruby
gem 'jettywrapper', '2.0.4'
gem 'jquery-color'
gem 'jquery-rails', '4.3.1'
gem 'nokogiri', '~> 1.10.0'
gem 'oga'
gem 'rails', '~> 4.2.0'
gem 'rsolr', '1.1.2'
gem 'sass-rails', '5.0.6'
gem 'sdoc', '0.4.2', group: :doc
gem 'solr_wrapper', '0.18.1'
gem 'sqlite3', '1.3.12', platforms: :ruby # we always need sqlite to the boundwiths database
gem 'summon', git: 'https://github.com/magibney/summon.rb', branch: 'sign-empty-param-values'
gem 'therubyracer', '0.12.2', platforms: :ruby
gem 'traject', '2.3.3'
gem 'tzinfo-data', '1.2017.2' # newer passenger docker image needs tzinfo-data installed for some reason
gem 'uglifier', '3.0.2'
gem 'unicorn'
# As of Blacklight v6.3.0, enabling turbolinks corrupts render of search nav.
# See https://github.com/projectblacklight/blacklight/issues/1562
# gem 'turbolinks', '5.0.1'

group :test, :production do
  gem 'mysql2', '~> 0.4.10'
end

group :production do
  gem 'passenger', '5.1.6', require: 'phusion_passenger/rack_handler'
end

group :development, :test do
  gem 'byebug', platforms: :ruby
end

group :development do
  gem 'dotenv-rails'
  gem 'pry-rails'
  gem 'web-console', '~> 2.0', platforms: :ruby
end
