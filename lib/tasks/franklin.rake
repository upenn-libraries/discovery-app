namespace :franklin do
  desc 'Start development/test environment'
  task :start do
    system('lando start')

    # Copy configset to proper location
    system('lando ssh gibneysolr -u solr -c "cp -r /app/solr/franklin /opt/solr/server/solr/configsets"')

    # Initialize solr
    system('lando ssh gibneysolr -u solr -c "/opt/solr/bin/solr start -c -m 2g -p 8983 -Dsolr.jetty.request.header.size=65536"')

    # Setup Collections
    system('lando ssh gibneysolr -u solr -c "/opt/solr/bin/solr create_collection -c franklin-dev -d franklin"')
    system('lando ssh gibneysolr -u solr -c "/opt/solr/bin/solr create_collection -c franklin-test -d franklin"')

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
end
