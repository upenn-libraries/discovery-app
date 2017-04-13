
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
  migrations (if you forget, it's fine; Rails will refuse to serve
  requests if you have migrations that aren't loaded yet.)

- Install Solr with
  [solrplugins](https://github.com/upenn-libraries/solrplugins). The following line should be added 
  to the file `solr-x.x.x/server/contexts/solr-jetty-context.xml` inside the 'Configure' tag:

  ```
  <Set name="extraClasspath">/path/to/solrplugins-0.1-SNAPSHOT.jar</Set>
  ```

- Add a solr core from the
  [library-solr-schema](https://gitlab.library.upenn.edu/discovery/library-solr-schema)
  repo.

- Load some test marc data into Solr:

  ```bash
  bundle exec rake solr:marc:index_test_data
  ```

  This pulls 30 sample records from
  [the Blacklight-Data repository](https://github.com/projectblacklight/blacklight-data).

  If the test data is successfully indexed, you should see output
  something like:
  
  ```bash
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


# JRuby and Traject

Using JRuby for indexing MARC records into Solr greatly improves
performance. BUT there are major known issues with regular expressions
in threads, causing intermittent (!) exceptions. For more information,
see these links:

- https://groups.google.com/forum/#!topic/traject-users/v_HDAyf2NQA
- https://groups.google.com/forum/#!topic/traject-users/cDqaU-YYQyI
- https://github.com/jruby/jruby/issues/4001

So we have elected NOT to use JRuby, but these instructions remain
here in case the situation changes.

First, install JRuby using [rvm](https://rvm.io/).

```
# standard steps to install rvm
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
\curl -sSL https://get.rvm.io | bash -s stable

# you may need to update rvm to head, in order to get support for
# jruby-9.1.2.0
rvm get head

# install jruby
rvm install jruby-9.1.2.0

# use it
rvm use jruby
```

From this repository's directory, run:

```
gem install bundler
bundle install
```

You can tweak the thread pool parameters for indexing in `app/models/marc_indexer.rb`

To index MARC files, use the `pennlib:marc:index` rake task, which
wraps `solr:marc:index`. The wrapper task can accept a glob for the
MARC_FILE variable:

```
# single file
bundle exec rake pennlib:marc:index MARC_FILE=/path/to/records.xml
# glob
bundle exec rake pennlib:marc:index MARC_FILE=/path/to/*.xml
```

Rails and Blacklight should run under JRuby too, though it's not clear
how well they run. Note that `bin/spring` has been patched to work
with JRuby.


# Docker

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

# optional: build the image that uses jruby/traject for indexing
docker build -f Dockerfile-jruby -t discovery-indexing-app --build-arg GIT_COMMIT=`git rev-parse --short HEAD` .
```

Save the image to a .tgz file, so you can deploy it to servers. We
might consider setting up our own Docker registry for storing images,
at some point.

```
docker save discovery-app:latest | gzip > discovery-app-latest.tgz
# copy it to the server
scp discovery-app-latest.tgz me@server.library.upenn.edu:docker_images
```

## Deploying the Image

ssh into the server, and load the image into docker:

```
gunzip -c docker_images/discovery-app-latest.tgz | docker load
```

Now you can start a container for the app:

```
# note the use of PASSENGER_APP_ENV instead of RAILS_ENV
docker run -p 80:80 \
       --env PASSENGER_APP_ENV=production \
       --env DEVISE_SECRET_KEY=REPLACE_WITH_REAL_KEY \
       --env SECRET_KEY_BASE=REPLACE_WITH_REAL_KEY \
       --env SOLR_URL=http://hostname:8983/solr/blacklight-core \
       discovery-app:latest
```

