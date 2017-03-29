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

if [ -z "$2" ]
then
    last_run=`cat $oai_dir/LAST_RUN`
else
    last_run="$2"
fi

if [ -z "$last_run" ]
then
    echo "ERROR: No argument supplied and $oai_dir/LAST_RUN file not found. Can't proceed."
    exit
fi

dir=$oai_dir/`date +"%Y_%m_%d_%k_%M"`

# format date as ISO8601, as expected by OAI
now=`date -u +"%Y-%m-%dT%H:%M:%SZ"`

mkdir -p $dir

./fetch_oai.rb $set_name "$last_run" $dir

echo $now > $oai_dir/LAST_RUN

./preprocess_oai.sh "$dir/$set_name*.xml"

./index_solr.sh "$dir/part*.xml"

./process_files.rb -p 4 -s delete_from_solr "$dir/$set_name*.xml"
