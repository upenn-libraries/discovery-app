#!/bin/bash
# index all the MARC XML files found in the passed-in directory argument

usage()
{
    echo "Usage: $0 DIR"
    echo "DIR is a directory path containing .xml files to index."
    exit 1
}

[ $# -gt 0 ] || usage

mkdir -p log/indexing

time ls $1/*.xml | sort | xargs -P 4 -t -I{} sh -c "bundle exec rake solr:marc:index MARC_FILE={} > log/indexing/\$(basename {} .xml).log 2> log/indexing/\$(basename {} .xml).log"
