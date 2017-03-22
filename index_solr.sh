#!/bin/bash
#
# Usage: ./index_solr.rb "/path/to/files/*.xml"
#
# Note the quoted glob.

time ./process_files.rb -l log/indexing -p 4 -i "$1" index_into_solr
