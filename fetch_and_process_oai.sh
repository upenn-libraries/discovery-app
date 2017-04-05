#!/bin/bash
#
# script that is meant to be run as a cron job, using jenkins, or
# through some other job scheduler.

set_name=allTitles

if [ -z "$1" ]
then
    echo "Usage: fetch_and_process_oai.sh OAI_DIR [FROM_TIMESTAMP]"
    exit
else
    oai_dir="$1"
fi

set_dir="$oai_dir/$set_name"
dir=$set_dir/`date +"%Y_%m_%d_%k_%M"`
mkdir -p $dir

if [ -z "$2" ]
then
    last_run=`cat $set_dir/LAST_RUN`
else
    last_run="$2"
fi

if [ -z "$last_run" ]
then
    echo "ERROR: No argument supplied and $oai_dir/LAST_RUN file not found. Can't proceed."
    exit
fi

# format date as ISO8601, as expected by OAI
now=`date -u +"%Y-%m-%dT%H:%M:%SZ"`

echo "#### OAI fetch and process started at `date`"

echo "Fetching from OAI"
./fetch_oai.rb $set_name "$last_run" $dir

echo "Updating LAST_RUN file"
echo $now > $set_dir/LAST_RUN

echo "Running preprocessing tasks"
./preprocess_oai.sh "$dir/$set_name*.xml"

echo "Indexing into Solr"
./index_solr.sh "$dir/part*.xml"

echo "Deleting from Solr"
./process_files.rb -p 4 -s delete_from_solr "$dir/$set_name*.xml"

echo "#### OAI fetch and process ended at `date`"
