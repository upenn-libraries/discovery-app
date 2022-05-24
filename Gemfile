source 'https://rubygems.org'

# required and confirmed in use
gem 'alma', git: 'https://github.com/tulibraries/alma_rb.git', tag: 'v0.3.0'
# TODO: switch back to official gem when PR #36 is accepted and makes it into a release
gem 'bento_search', git: 'https://github.com/upenn-libraries/bento_search', branch: 'search_controller_engine_params' #'1.7'
gem 'blacklight', '6.8.0', git: 'https://github.com/magibney/blacklight.git', branch: 'v6.8.0-solr7-qq-feedFormat'
gem 'blacklight-marc', '6.2.0'
gem 'blacklight-ris', git: 'https://github.com/upenn-libraries/blacklight-ris.git'
gem 'blacklight_advanced_search', '6.3.1'
gem 'blacklight_alma', git: 'https://github.com/upenn-libraries/blacklight_alma.git'
gem 'blacklight_dynamic_sitemap'
gem 'blacklight_solrplugins', git: 'https://github.com/upenn-libraries/blacklight_solrplugins.git'
gem 'bootstrap_form', '= 2.7.0'
gem 'browserify-rails'
gem 'coffee-rails', '4.2.1'
gem 'devise', '~> 4'
gem 'devise-guests', '0.5.0'
gem 'faraday'
gem 'font-awesome-rails'
gem 'honeybadger'
gem 'httparty'
gem 'jbuilder', '2.6.0'
gem 'jquery-rails', '4.3.1'
gem 'mysql2', '~> 0.4.10'
gem 'nokogiri', '~> 1.13.6'
gem 'oj'
gem 'rails', '~> 4.2.0'
gem 'rsolr', '1.1.2'
gem 'sass-rails', '5.0.6'
gem 'sdoc', '0.4.2', group: :doc
gem 'select2-rails'
gem 'sqlite3', '1.3.12', platforms: :ruby # we always need sqlite to the boundwiths database
# TODO: switch back to official gem when PR #21 is accepted and makes it into a release
gem 'summon', git: 'https://github.com/magibney/summon.rb', branch: 'sign-empty-param-values'
gem 'therubyracer', '0.12.2', platforms: :ruby
gem 'traject', '2.3.3'
gem 'typhoeus'
gem 'tzinfo-data', '1.2017.2' # newer passenger docker image needs tzinfo-data installed for some reason
gem 'uglifier', '3.0.2'

group :development do
  gem 'dotenv-rails'
  gem 'web-console', '~> 2.0', platforms: :ruby
end

group :development, :test do
  gem 'byebug', platforms: :ruby
  gem 'rspec-rails'
  gem 'webmock'
end
