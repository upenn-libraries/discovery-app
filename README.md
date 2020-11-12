
# Nouveau Franklin

## Development Setup

- Clone this repo
- Install Ruby `2.3.3` ([rbenv](https://github.com/rbenv/rbenv) recommended)
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
- Configure Solr
  - You can get the production Solr URL and use that, assuming you're on the Penn VPN
  - Otherwise, you can run Penn's custom Solr locally using Lando
    - `franklin:start` to pull and start the Solr container
    - `franklin:stop` when you're done working
    - `franklin:clean` when things get weird
- Start the rails server:

  ```bash
  bundle exec rails s
  ```

- Open up [localhost:3000](localhost:3000) in a browser.  If
  everything went well, you should see the Franklin homepage.

## Solr Indexing

This repository also contains Traject code for indexing MARC records
into Solr. It isn't separate because we want to consolidate the MARC
parsing logic, as some of it is used to generate display values
on-the-fly at page render time.

We handle two types of data exports from Alma: full exports and
incremental updates via OAI.

The commands in this section can be run directly, or in an application
container. See the `run_in_container.sh` wrapper script in the ansible
repository.

### Full exports

Transfer the *.tar.gz files created by the Alma publishing job to the
directory where they will be preprocessed and indexed. Run these commands:

```bash
./preprocess.sh /var/solr_input_data/alma_prod_sandbox/20170412_full allTitles

./index_solr.sh /var/solr_input_data/alma_prod_sandbox/20170412_full/processed
```

### Incremental updates (OAI)

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

## Building Docker Images

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

# Running Tests

Tests require a locally-installed version of Chrome to support feature specs

The usual ENV variables need to be set, for now

- DL Chrome @ `https://commondatastorage.googleapis.com/chromium-browser-snapshots/index.html?prefix=Linux_x64/737173/`
- Extract to `PATH_OF_YOUR_CHOOSING`
- Precompile assets for `test` (why???): `RAILS_ENV=test bundle exec rake assets:precompile`
- Start dockerized UPenn Solr `rake franklin:start`
- Run suite: `RAILS_ENV=test rspec`

# Auditing Secrets

You can use [Gitleaks](https://github.com/upenn-libraries/gitleaks) to check the repository for unencrypted secrets that have been committed.

```
docker run --rm --name=gitleaks -v $PWD:/code quay.io/upennlibraries/gitleaks:v1.23.0 -v --repo-path=/code --repo-config
```

Any leaks will be logged to `stdout`. You can add the `--redact` flag if you do not want to log the offending secrets.
