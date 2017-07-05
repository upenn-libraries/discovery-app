#!/bin/bash
#
# Note that directory should be dir containing the fetched raw OAI files

batch_dir=$1
set_name=$2

echo "Indexing into Solr"
./index_solr.sh "$batch_dir/processed"

echo "Deleting from Solr"
find "$batch_dir" -maxdepth 1 -name $set_name'*.xml.gz' | xargs -P $NUM_INDEXING_PROCESSES -t -I FILENAME bundle exec rake pennlib:oai:delete_ids OAI_FILE=FILENAME

echo "Issuing commit"
curl --silent --show-error -m 900 $SOLR_URL/update --data '<commit/>' -H 'Content-type:text/xml; charset=utf-8'
