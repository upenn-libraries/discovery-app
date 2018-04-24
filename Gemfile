source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.8'

# we always need sqlite to the boundwiths database
gem 'sqlite3', '1.3.12', platforms: :ruby

group :test, :production do
  gem 'mysql2', '0.4.5'
end

gem 'jdbc-sqlite3', '3.8.11.2', platforms: :jruby

gem 'activerecord-jdbcmysql-adapter', '1.3.21', platforms: :jruby

# Use SCSS for stylesheets
gem 'sass-rails', '5.0.6'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '3.0.2'

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '4.2.1'

# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'therubyracer', '0.12.2', platforms: :ruby

gem "blacklight", '6.8.0', :git => 'https://github.com/magibney/blacklight.git', :branch => 'v6.8.0-solr7-qq'

gem "jettywrapper", '2.0.4'

# newer passenger docker image needs tzinfo-data installed for some reason
gem 'tzinfo-data', '1.2017.2'

gem "solr_wrapper", '0.18.1'

gem 'browserify-rails', '4.0.0'

# Use jquery as the JavaScript library
gem 'jquery-rails', '4.3.1'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
# As of Blacklight v6.3.0, enabling turbolinks corrupts render of search nav.
# See https://github.com/projectblacklight/blacklight/issues/1562
# gem 'turbolinks', '5.0.1'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '2.6.0'

# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '0.4.2', group: :doc

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Unicorn as the app server
# gem 'unicorn'

gem 'passenger', '5.1.6', require: 'phusion_passenger/rack_handler'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: :ruby
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0', platforms: :ruby

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # Removed because spring often causes problems with gem reloading
  # gem 'spring'
end

gem 'rsolr', '1.1.2'

gem 'globalid', '0.3.7'

gem 'devise', '4.2.1'

gem 'devise-guests', '0.5.0'

gem 'blacklight_range_limit', '6.0.0'

gem 'traject', '2.3.3'

gem 'nokogiri', '1.7.1'

gem 'blacklight-marc', '6.2.0'

gem 'blacklight_advanced_search', '6.3.1'

# TODO: switch back to official gem when PR #36 is accepted and makes it into a release
gem 'bento_search', :git => 'https://github.com/magibney/bento_search', :branch => 'search_controller_engine_params' #'1.7'

# TODO: switch back to official gem when PR #21 is accepted and makes it into a release
gem 'summon', :git => 'https://github.com/magibney/summon.rb', :branch => 'sign-empty-param-values'

gem 'blacklight_solrplugins', :git => 'https://github.com/upenn-libraries/blacklight_solrplugins.git'

gem 'blacklight_alma', :git => 'https://github.com/upenn-libraries/blacklight_alma.git'

gem 'blacklight-ris', :git => 'https://github.com/upenn-libraries/blacklight-ris.git'
