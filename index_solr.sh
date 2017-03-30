#!/bin/bash

export LOG_DIR=log/indexing

time ./process_files.rb -p 4 -s index_into_solr "$@" 
