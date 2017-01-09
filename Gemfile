source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.7'

# Use sqlite3 as the database for Active Record
gem 'sqlite3', '1.3.12', platforms: :ruby

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

gem "blacklight", '6.7.2'

gem "jettywrapper", '2.0.4'

gem 'tzinfo-data', '1.2016.7', platforms: [:mingw, :mswin, :x64_mingw]

gem "solr_wrapper", '0.18.1'

# Use jquery as the JavaScript library
gem 'jquery-rails', '4.2.1'

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

gem 'passenger', '5.0.30', require: 'phusion_passenger/rack_handler'

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

gem 'devise', '4.2.0'

gem 'devise-guests', '0.5.0'

gem 'blacklight_range_limit', '6.0.0'

gem 'traject', '2.3.2'

# TODO: Using this version, corrects error for getting format from 008 field,
# currently breaks in original project.  PR out to original project,
# will switch back when applied.
gem 'blacklight-marc', '~> 6.0', :git => 'https://github.com/magibney/blacklight-marc.git', :branch => 'fix-extract_marc-format-008'

gem 'blacklight_solrplugins', :git => 'https://github.com/upenn-libraries/blacklight_solrplugins.git'

gem 'bento_search', '1.6.1'

gem 'blacklight_alma', :git => 'https://github.com/upenn-libraries/blacklight_alma.git', :branch => 'iframe-toggle-on-search-results'

gem 'ezwadl', :git => 'https://github.com/upenn-libraries/ezwadl.git'

# TODO: switch back to gem when they make a release newer than 6.2.1,
# so that we get PR #70
#gem 'blacklight_advanced_search', '6.1.0'
gem 'blacklight_advanced_search', :git => 'https://github.com/codeforkjeff/blacklight_advanced_search.git'
