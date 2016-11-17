#!/bin/bash
#
# runs Solr indexing using JRuby, in a docker container

CONTAINER_NAME="discovery-indexing-app-container"
IMAGE_NAME="discovery-indexing-app"
SCRIPT_PATH="$(readlink -f ${BASH_SOURCE[0]})"
# dir of this script, which should also be root of the repo
SCRIPT_DIR="$(dirname $SCRIPT_PATH)"

usage()
{
    echo "Usage: $0 MARC_FILE"
    echo "MARC_FILE needs to exist in the current directory"
    echo "tree, or container won't be able to access it."
    exit 1
}

[ $# -gt 0 ] || usage

# remove old container image if there is one
docker ps -a | grep $CONTAINER_NAME > /dev/null
if [ $? == 0 ]; then
    echo "Removing existing image named $CONTAINER_NAME"
    docker rm $CONTAINER_NAME
fi

echo "Running indexing rake task"
docker run --name $CONTAINER_NAME \
       -e MARC_FILE="data/$1" \
       -e SOLR_URL=http://solr-test.library.upenn.int:8983/solr/test_core \
       -v /opt/discovery:/opt/discovery/data \
       $IMAGE_NAME
