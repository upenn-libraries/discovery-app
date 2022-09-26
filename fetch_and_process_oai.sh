#!/bin/bash

# script that is meant to be run as a cron job, using jenkins, or
# through some other job scheduler.

# Currently the cron runs this as:
# cd /opt/discovery && ./run_in_container.sh ./fetch_and_process_oai.sh /var/solr_input_data/alma_production/oai >> /opt/discovery/log/fetch_and_process_oai.log 2>> /opt/discovery/log/fetch_and_process_oai.log


set_name=allTitles
skip_indexing=false

if [ -z "$1" ]
then
    echo "Usage: fetch_and_process_oai.sh [--skip-indexing] OAI_DIR [FROM_TIMESTAMP]"
    exit
else
    if [ "$1" = "--skip-indexing" ]
    then
      skip_indexing=true
      shift
    fi
    oai_dir="$1"
fi

set_dir="$oai_dir/$set_name"
batch_dir=$set_dir/`date +"%Y_%m_%d_%H_%M"`
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
echo "Command: ./fetch_oai.rb $set_name "$last_run" "$now" $batch_dir"
./fetch_oai.rb $set_name "$last_run" "$now" $batch_dir

if [ $? != 0 ]; then
    echo "ERROR: Something went wrong running fetch_oai.rb. Exiting script."
    exit 1
fi
    
echo "Updating LAST_RUN file"
echo $now > $set_dir/LAST_RUN

echo "Running preprocessing tasks"
./preprocess_oai.sh "$batch_dir" "$set_name"

if [ "$skip_indexing" = false ]
then
  echo "Running index_and_deletions.sh"
  ./index_and_deletions.sh "$batch_dir" "$set_name"
else
  echo "Skipping indexing"
fi

echo "#### OAI fetch and process ended at `date`"
