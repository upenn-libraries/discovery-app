require 'fileutils'
require 'open-uri'
require 'rubygems/package'
require 'zlib'

namespace :franklin do
  desc 'Start development/test environment Solr instance'
  task :start do
    system('lando start')

    # Start solr
    system('lando ssh gibneysolr -u solr -c "/opt/solr/bin/solr start -c -m 2g -p 8983 -Dsolr.jetty.request.header.size=65536"')

    puts "      Services initialized! Please create Solr collections with franklin:solrconfig if you haven't already"

    # No Lando DB for now
    # # Create databases, if they aren't present.
    # system('rake db:create')
    #
    # # Migrate test and development databases
    # system('RACK_ENV=development rake db:migrate')
    # system('RACK_ENV=test rake db:migrate')
  end

  desc 'Stop development/test environment'
  task :stop do
    system('lando stop')
  end

  desc 'Cleans development/test environment'
  task :clean do
    system('lando destroy -y')
  end

  desc 'Update Solr config from repo and recreate Solr collections'
  task :solrconfig do
    system('lando start') # TODO: check if already started?

    solr_config_path = File.join Rails.root, 'solr_conf'

    # clear out old config
    FileUtils.rm_rf(Dir.glob(File.join(solr_config_path, '*')))

    # Pull configset based on branch parameter, if present
    solr_config_branch = ENV['SOLR_CONFIG_BRANCH'] || 'stable'
    solr_config_name = "franklin-solr-config-#{solr_config_branch}"
    config_download_path = "https://gitlab.library.upenn.edu/franklin/franklin-solr-config/-/archive/#{solr_config_branch}/#{solr_config_name}.tar.gz"

    # download file to Tempfile
    tar_file = URI(config_download_path).open

    # extract files
    tar_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open(tar_file))
    tar_extract.rewind
    tar_extract.each do |entry|
      if entry.directory?
        Dir.mkdir File.join solr_config_path, entry.full_name
      elsif entry.file?
        File.open(
          File.join(solr_config_path, entry.full_name),
          'a+:ASCII-8BIT' # use proper encoding for new files
        ) do |f|
          f.write entry.read
        end
      end
    end
    tar_extract.close

    # delete existing collections
    # TODO: only if they exist?
    system("lando ssh gibneysolr -u solr -c '/opt/solr/bin/solr delete -c franklin-dev'")
    system("lando ssh gibneysolr -u solr -c '/opt/solr/bin/solr delete -c franklin-test'")

    # Copy configset to proper location
    system("lando ssh gibneysolr -u solr -c 'cp -r /app/solr_conf/#{solr_config_name} /opt/solr/server/solr/configsets/#{solr_config_name}'")

    # recreate solr collections
    system("lando ssh gibneysolr -u solr -c '/opt/solr/bin/solr create_collection -c franklin-dev -d #{solr_config_name}'")
    system("lando ssh gibneysolr -u solr -c '/opt/solr/bin/solr create_collection -c franklin-test -d #{solr_config_name}'")
  end
end
