#!/bin/bash

batch_dir=$1
set_name=$2

echo "Indexing into Solr"
./index_solr.sh "$batch_dir/part*.xml"

echo "Deleting from Solr"
./process_files.rb -p $NUM_INDEXING_PROCESSES -s delete_from_solr "$batch_dir/$set_name*.xml"
