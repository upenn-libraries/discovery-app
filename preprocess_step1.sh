#!/bin/bash

cat=cat
# if [ -f /home/jeffchiu/bypass_page_cache/direct_io.sh ]; then
#     cat="/home/jeffchiu/bypass_page_cache/direct_io.sh -r"
# fi

filename=$1
dir=`dirname $filename`
output_dir=$dir/processed
base_filename=`basename "${filename%%.*}"`
part_filename="${base_filename%.*}".xml
num=`echo $base_filename | grep -E -o "[0-9]+$"`

mkdir -p $output_dir

$cat $filename \
    | tar -xzO \
    | sed 's/<collection>/<collection xmlns="http:\/\/www.loc.gov\/MARC21\/slim">/' \
    | gzip --stdout \
    | tee $output_dir/$part_filename.gz \
    | gunzip --stdout \
    | saxon -xsl:$XSL_DIR/boundwith_holdings.xsl - \
    | gzip --stdout > $output_dir/boundwiths_$num.xml.gz
