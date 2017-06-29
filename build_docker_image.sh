#!/bin/bash

# This script is meant to be run from a fresh clone/checkout of the
# git repository, not from your "working" clone, which may have stray
# files and other artifacts that shouldn't be in the build.

rev=`git rev-parse --short HEAD`
current_branch=`git rev-parse --abbrev-ref HEAD`

if [ "$#" -ne 1 ]; then
    branch=$current_branch
else
    branch=$1
fi

git checkout $branch
git pull

docker build -t indexing-dev.library.upenn.int:5000/upenn-libraries/discovery-app:$branch --build-arg GIT_COMMIT=$rev .

echo
echo "###########################################"
echo "DON'T FORGET! To push to the registry, run:"
echo "  docker push indexing-dev.library.upenn.int:5000/upenn-libraries/discovery-app:$branch"
