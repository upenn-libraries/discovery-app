require 'fileutils'
require 'open-uri'
require 'rubygems/package'
require 'zlib'
require 'penn_lib/lando'

namespace :franklin do
  desc 'Start development/test environment Solr instance'
  task :start do
    system('lando start')

    # Start solr
    PennLib::Lando.start_solr

    if PennLib::Lando.collections_exist?
      puts "\nServices initialized!"
    else
      Rake::Task['franklin:solrconfig'].invoke
    end

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
    solr_config_path = File.join Rails.root, 'tmp', 'solr_conf'

    # create solr_config_path if it doesnt already exist
    FileUtils.mkdir solr_config_path unless Dir.exist? solr_config_path

    # clear out old config
    FileUtils.rm_rf(Dir.glob(File.join(solr_config_path, '*')))

    # Pull configset based on branch parameter, if present
    solr_config_branch = ENV['SOLR_CONFIG_BRANCH'] || 'stable'
    solr_config_name = "franklin-solr-config-#{solr_config_branch}"
    # eventually, this will be a public URL - but not yet - VPN needed
    config_download_path = "https://gitlab.library.upenn.edu/franklin/franklin-solr-config/-/archive/#{solr_config_branch}/#{solr_config_name}.tar.gz"

    # download file to Tempfile
    begin
      tar_file = URI(config_download_path).open
    rescue StandardError => _e
      puts "Problem retrieving Solr config - are you on the VPN? Are you sure branch '#{solr_config_branch}' exists?"
      next # exit
    end

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
    if PennLib::Lando.collections_exist?
      PennLib::Lando.delete_collection 'franklin-test'
      PennLib::Lando.delete_collection 'franklin-dev'
    end

    PennLib::Lando.copy_config solr_config_name

    # create solr collections
    PennLib::Lando.create_collection 'franklin-test', solr_config_name
    PennLib::Lando.create_collection 'franklin-dev', solr_config_name
  end
end
