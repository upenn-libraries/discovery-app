#!/bin/bash
#
# Index a single MARC .xml.gz file

filename=$1
dir=`dirname $filename`
base_filename=`basename "$filename"`
base_filename="${base_filename%%.*}"

mkdir -p $dir/log

zcat $filename | bundle exec rake pennlib:marc:index_from_stdin[$filename] >> $dir/log/$base_filename.log 2>&1
