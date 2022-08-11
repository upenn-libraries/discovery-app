
# Nouveau Franklin

## Running Local Development Environment with Lando
We are using [lando](https://docs.lando.dev/basics/) to set up a local Solr image for development. We have some custom rake tasks that wrap lando commands and run other necessary tasks to initialize the Solr instance properly.

### Installing System Requirements
#### Install Ruby 2.3.3
Install Ruby 2.3.3 with [rbenv](https://github.com/rbenv/rbenv) or [RVM](https://rvm.io/).
#### Install Node 14 (or earlier)
This application requires an older version of Node to prevent changes from being required in the `package-lock.json`.
##### Mac
```
brew install node@14
```
#### Install Lando
##### Mac
```
brew cask install lando
```

##### Linux
See the [lando website](https://docs.lando.dev/basics/installation.html#linux) for installation options

### Running Development Services

#### Starting
This installs the necessary gems and javascript libraries, then it starts a Solr service. If the container isn't yet present on your system, it will build one and load in the `GibneySolr` customizations and the Solr configuration from from [this Gitlab repo](https://gitlab.library.upenn.edu/franklin/franklin-solr-config/).
```
bundle install
npm install
bundle exec rake franklin:start
```
#### Stopping
Stops running Solr instance.
```
bundle exec rake franklin:stop
```

#### Starting Fresh
This destroys the Solr container.
```
bundle exec rake franklin:clean
```

#### Indexing some sample record
Use the defaults or add some JSON to `sample_index_data.json`
```
bundle exec rake franklin:load_sample_data
```

#### Starting application
To view application in browser at `localhost:3000`, run:
```
rails s
```

## Old School Installation

- Checkout this repo.

- Make sure you have ruby 2.3.3 installed. It's recommended that you
  use [rbenv](https://github.com/rbenv/rbenv), but it may be
  quicker/easier to get running with [rvm](https://rvm.io/).
  - You may have issues installing Ruby 2.3.3 in recent Linux distributions due to an OpenSSL version incompatibility. See [this guide](https://www.garron.me/en/linux/install-ruby-2-3-3-ubuntu.html) for help.

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

- If there isn't a Solr instance you can use, you'll need to install
  Solr and add the
  [solrplugins](https://github.com/upenn-libraries/solrplugins)
  extensions to it. The following line should be added to the file
  `solr-x.x.x/server/contexts/solr-jetty-context.xml` inside the
  'Configure' tag:

  ```
  <Set name="extraClasspath">/path/to/solrplugins-0.1-SNAPSHOT.jar</Set>
  ```

  Add the solr core from the
  [library-solr-schema](https://gitlab.library.upenn.edu/discovery/library-solr-schema)
  repo. You can copy the core's directory into `solr-x.x.x/server/solr`

  Load some test marc data into Solr:

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

# Docker

There is a `build_docker_image.sh` script you can use to build docker
images from specific branches that have been freshly pulled from
origin. It's intended to be run from a repository clone whose sole
purpose is to do builds, so that the images aren't polluted with misc
files you may have lying around. Run it with the branch name:

``` bash
./build_docker_image.sh master
# remember to push to the registry afterwards! see the output of the script.
```

See the
[deploy-docker](https://gitlab.library.upenn.edu/ansible/deploy-discovery)
repository for Ansible scripts that build Docker images and deploy containers
to the test and production environments.

# Auditing Secrets

You can use [Gitleaks](https://github.com/upenn-libraries/gitleaks) to check the repository for unencrypted secrets that have been committed.

```
docker run --rm --name=gitleaks -v $PWD:/code quay.io/upennlibraries/gitleaks:v1.23.0 -v --repo-path=/code --repo-config
```

Any leaks will be logged to `stdout`. You can add the `--redact` flag if you do not want to log the offending secrets.
