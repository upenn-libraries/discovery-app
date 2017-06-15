
# JRuby and Traject

DO NOT USE: Using JRuby for indexing MARC records into Solr greatly
improves performance. BUT there are major known issues with regular
expressions in threads, causing intermittent (!) exceptions. For more
information, see these links:

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

Build the image that uses jruby/traject for indexing. This dockerfile
probably needs updating.

```
docker build -f Dockerfile-jruby -t discovery-indexing-app --build-arg GIT_COMMIT=`git rev-parse --short HEAD` .
```
