#!/bin/bash

#git checkout develop

#git pull

docker build -t discovery-app --build-arg GIT_COMMIT=`git rev-parse --short HEAD` .

# tag and push to our repository
docker tag discovery-app:latest indexing-dev.library.upenn.int:5000/upenn-libraries/discovery-app:latest
docker push indexing-dev.library.upenn.int:5000/upenn-libraries/discovery-app:latest
