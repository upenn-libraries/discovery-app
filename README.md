
# Nouveau Franklin

Installation:

- Checkout this repo.

- Make sure you have ruby 2.3.1 installed. It's recommended that you
  use [rbenv](https://github.com/rbenv/rbenv), but it may be
  quicker/easier to get running with [rvm](https://rvm.io/).

- Run `bundle install` to install all gem dependencies.

- Run `npm install` to install javascript libraries.

- Edit the `local_dev_env` file and populate the variables with
  appropriate values. Then source it in your shell.

  ```bash
  source local_dev_env
  ```

- Run `bundle exec rake db:migrate` to initialize the database. You'll
  also have run this again whenever you pull code that includes new
  migrations (if you forget, Rails will raise an exception when serving
  requests because there are unloaded migrations.)

- Install Solr and add the
  [solrplugins](https://github.com/upenn-libraries/solrplugins)
  extensions to it. The following line should be added to the file
  `solr-x.x.x/server/contexts/solr-jetty-context.xml` inside the
  'Configure' tag:

  ```
  <Set name="extraClasspath">/path/to/solrplugins-0.1-SNAPSHOT.jar</Set>
  ```

- Add the solr core from the
  [library-solr-schema](https://gitlab.library.upenn.edu/discovery/library-solr-schema)
  repo. You can copy the core's directory into `solr-x.x.x/server/solr`

- Load some test marc data into Solr:

  ```bash
  bundle exec rake solr:marc:index_test_data
  ```

  This pulls 30 sample records from
  [the Blacklight-Data repository](https://github.com/projectblacklight/blacklight-data).

  If the test data is successfully indexed, you should see output
  something like:
  
  ```
  2016-03-03T12:29:40-05:00  INFO    Traject::SolrJsonWriter writing to 'http://127.0.0.1:8983/solr/blacklight-core/update/json' in batches of 100 with 1 bg threads
  2016-03-03T12:29:40-05:00  INFO    Indexer with 1 processing threads, reader: Traject::MarcReader and writer: Traject::SolrJsonWriter
  2016-03-03T12:29:41-05:00  INFO Traject::SolrJsonWriter sending commit to solr at url http://127.0.0.1:8983/solr/blacklight-core/update/json...
  2016-03-03T12:29:41-05:00  INFO finished Indexer#process: 30 records in 0.471 seconds; 63.8 records/second overall.
  ```

- Start the rails server:

  ```bash
  bundle exec rails s
  ```

- Open up [localhost:3000](localhost:3000) in a browser.  If
  everything went well, you should see the generic Blacklight homepage
  and have 30 faceted records to search.

# Solr Indexing

This repository also contains Traject code for indexing MARC records
into Solr. It isn't separate because we want to consolidate the MARC
parsing logic, as some of it is used to generate display values
on-the-fly at page render time.

We handle two types of data exports from Alma: full exports and
incremental updates via OAI.

The commands in this section can be run directly, or in an application
container. See the `run_in_container.sh` wrapper script in the ansible
repository.

## Full exports

Transfer the *.tar.gz files created by the Alma publishing job to the
directory where they will be preprocessed and indexed. Run these commands:

```bash
./preprocess.sh /var/solr_input_data/alma_prod_sandbox/20170412_full allTitles

./index_solr.sh /var/solr_input_data/alma_prod_sandbox/20170412_full/processed
```

## Incremental updates (OAI)

This runs via a cron job, which fetches the updates available via OAI
since the last time the job was run.

```bash
./fetch_and_process_oai.sh /var/solr_input_data/alma_prod_sandbox/oai
```

If you do a full index using an older full data export, and you want
to apply a set of already fetched and processed OAI updates manually,
you can do so like this:

```bash
# run this for each dated directory
./index_and_deletions.sh /var/solr_input_data/alma_prod_sandbox/oai/allTitles/2017_04_10_00_00 allTitles
```

# JRuby and Traject

See the `jruby-traject.md` file for details on how to use JRuby with
Traject, which is currently broken.

# Docker

See the
[deploy-docker](https://gitlab.library.upenn.edu/ansible/deploy-discovery)
repository for Ansible scripts that use Docker to deploy the
application in test and production environments.

## Building the Image(s)

It's best to run this command from a separate, clean clone of this
repository, so that your build doesn't pick up files lying around in
the repo where you do development.

Note that Gemfile.lock stores a commit hash for git repos it depends
upon. If such a dependency is updated, remember to run `bundle update
--source gem` in THIS repo and commit the change.

```
# checkout the branch you want to build the image for
git checkout develop

# build it
docker build -t discovery-app --build-arg GIT_COMMIT=`git rev-parse --short HEAD` .

# tag the image and push it to our private registry
docker tag discovery-app:latest indexing-dev.library.upenn.int:5000/upenn-libraries/discovery-app:latest
docker push indexing-dev.library.upenn.int:5000/upenn-libraries/discovery-app:latest

# if a registry isn't available, you can copy images 'manually'
#docker save discovery-app:latest | gzip > discovery-app-latest.tgz
#scp discovery-app-latest.tgz me@server.library.upenn.edu:docker_images
```

## Deploying the Image

ssh into the server, and load the image into docker:

```
docker pull indexing-dev.library.upenn.int:5000/upenn-libraries/discovery-app:latest
```

Now you can start a container for the app:

```
# note the use of PASSENGER_APP_ENV instead of RAILS_ENV
docker run -p 80:80 \
       --env PASSENGER_APP_ENV=production \
       --env DEVISE_SECRET_KEY=REPLACE_WITH_REAL_KEY \
       --env SECRET_KEY_BASE=REPLACE_WITH_REAL_KEY \
       --env SOLR_URL=http://hostname:8983/solr/blacklight-core \
       indexing-dev.library.upenn.int:5000/upenn-libraries/discovery-app:latest
```
