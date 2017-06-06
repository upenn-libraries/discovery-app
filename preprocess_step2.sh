#!/bin/bash

filename=$1
dir=`dirname $filename`
output_dir=$dir
base_filename=`basename "${filename%%.*}"`
num=`echo $base_filename | grep -E -o "[0-9]+$"`

gunzip $filename --stdout \
    | stdbuf -oL saxon -xsl:$XSL_DIR/fix_alma_prod_marc_records.xsl - \
    | bundle exec rake pennlib:marc:merge_boundwiths \
    | xmllint --format - \
    | gzip --stdout > $output_dir/part_$num.xml.gz
