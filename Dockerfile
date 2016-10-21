
# Build a container for running the application using nginx+passenger.
#
# See https://github.com/phusion/passenger-docker
#
# This uses a fairly heavyweight base image that seems well thought
# out, but is highly opinionated in how you do things (paths where it
# expects things, how to do container start-up scripts, etc) so it's
# worth spending some time with the docs.

FROM phusion/passenger-ruby23:0.9.19

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

#### START of app-specific stuff

RUN mkdir -p /home/app/webapp

# copy Gemfiles first: this takes advantage of caching during build
ADD Gemfile /home/app/webapp
ADD Gemfile.lock /home/app/webapp

WORKDIR /home/app/webapp

RUN bundle install

# everything after this ADD typically won't get cached by docker build
ADD . /home/app/webapp

RUN chown app.app -R /home/app/webapp

RUN mkdir -p /home/app/webapp/log
RUN chown app.app -R /home/app/webapp/log
RUN chmod ug+rw -R /home/app/webapp/log

RUN mkdir -p /home/app/webapp/tmp
RUN chown app.app -R /home/app/webapp/tmp
RUN chmod ug+rw -R /home/app/webapp/tmp

# enable nginx
RUN rm -f /etc/service/nginx/down

RUN rm /etc/nginx/sites-enabled/default
ADD nginx/webapp.conf /etc/nginx/sites-enabled/webapp.conf
ADD nginx/webapp-env.conf /etc/nginx/main.d/webapp-env.conf

# TODO: precompile assets at container startup because it needs env
# vars; is there a clean way to do this as part of build instead?
RUN echo "#!/bin/bash" > /etc/my_init.d/50_precompile_assets.sh
RUN echo "cd /home/app/webapp && bundle exec rake assets:precompile" >> /etc/my_init.d/50_precompile_assets.sh
RUN echo "chown -R app:app /home/app/webapp" >> /etc/my_init.d/50_precompile_assets.sh
RUN chmod a+rx /etc/my_init.d/50_precompile_assets.sh

RUN echo "#!/bin/bash" > /etc/my_init.d/60_db_migrate.sh
RUN echo "cd /home/app/webapp && bundle exec rake db:migrate" >> /etc/my_init.d/60_db_migrate.sh
RUN echo "chown -R app:app /home/app/webapp/db" >> /etc/my_init.d/60_db_migrate.sh
RUN chmod a+rx /etc/my_init.d/60_db_migrate.sh
  
#### END of app-specific stuff

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
