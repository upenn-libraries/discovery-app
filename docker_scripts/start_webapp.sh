#!/bin/bash
docker run -d -p 80:80 \
  --env-file .docker-environment \
  -v /opt/discovery/log:/home/app/webapp/log \
  --name discovery-app-container \
  discovery-app:latest
