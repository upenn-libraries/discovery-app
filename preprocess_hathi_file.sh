#!/bin/bash

cat_program=cat

filename=$1
dir=`dirname $filename`
output_dir=$dir/processed
base_filename=`basename "${filename}"`
part_filename=part_"${base_filename%.*}".xml

mkdir -p $output_dir

$cat_program $filename \
    | gunzip --stdout \
    | saxon -xsl:$XSL_DIR/hathi_oai2marc.xsl - \
    | gzip --stdout \
    > $output_dir/$part_filename.gz
