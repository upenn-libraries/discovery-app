#!/bin/bash
#
# Note that directory should be dir containing the fetched raw OAI files

batch_dir=$1
set_name=$2

echo "Indexing into Solr"
./index_solr.sh "$batch_dir/processed"

echo "Deleting from Solr"
find $INPUT_FILES_DIR -name $set_name'*.xml' | xargs -P $NUM_INDEXING_PROCESSES -t -I FILENAME bundle exec rake pennlib:oai:delete_ids OAI_FILE=FILENAME
