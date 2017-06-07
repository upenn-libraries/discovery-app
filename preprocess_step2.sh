#!/bin/bash

filename=$1
dir=`dirname $filename`
output_dir=$dir
base_filename=`basename "${filename%%.*}"`
num=`echo $base_filename | grep -E -o "[0-9]+$"`

# if we feed the output from saxon into merge_boundwiths, we get
# intermittent parse errors from Nokogiri when executing in the
# (somewhat slow) VM infrastructure. Nokogiri's Reader class seems
# picky about having enough data as it reads from stdin.
#
# perhaps the reason why putting xmllint before it works is that
# xmllint is actually reading the entire stream contents into memory?
# maybe? which would defeat the point of the streaming pipeline. but
# for now, I'm leaving this alone. -- jeff

gunzip $filename --stdout \
    | saxon -xsl:$XSL_DIR/fix_alma_prod_marc_records.xsl - \
    | xmllint --format - \
    | bundle exec rake pennlib:marc:merge_boundwiths \
    | gzip --stdout > $output_dir/part_$num.xml.gz
