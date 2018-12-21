#!/bin/bash
#
# Index all the part*.xml.gz files in the directory argument

input_files_dir="$1"

find $input_files_dir -name 'part*.xml.gz' \
    | xargs -P $NUM_INDEXING_PROCESSES -t -I FILENAME ./index_solr_file.sh FILENAME

if [ "$SOLR_UPDATE_COMMIT" != "false" ]; then
  curl --silent --show-error -m 900 $SOLR_URL/update --data '<commit/>' -H 'Content-type:text/xml; charset=utf-8'
fi
