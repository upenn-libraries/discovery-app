
# Running this application in docker

TODO: figure out ways to automate this stuff.

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
