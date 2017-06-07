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
batch_dir=$set_dir/`date +"%Y_%m_%d_%k_%M"`
mkdir -p $batch_dir

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

echo "############################################################"
echo "#### OAI fetch and process started at `date`"

echo "Fetching from OAI"
./fetch_oai.rb $set_name "$last_run" "$now" $batch_dir

if [ $? != 0 ]; then
    echo "ERROR: Something went wrong running fetch_oai.rb. Exiting script."
    exit 1
fi
    
echo "Updating LAST_RUN file"
echo $now > $set_dir/LAST_RUN

echo "Running preprocessing tasks"
./preprocess_oai.sh "$batch_dir" "$set_name"

echo "Running index_and_deletions.sh"
./index_and_deletions.sh "$batch_dir" "$set_name"

echo "#### OAI fetch and process ended at `date`"
