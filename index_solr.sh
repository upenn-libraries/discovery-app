#!/bin/bash

time ./process_files.rb -l log/indexing -p 4 -s index_into_solr "$@" 
