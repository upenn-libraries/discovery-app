#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: preprocess.sh input_files_dir set_name"
    echo
    echo "input_files_dir is a directory that contains .tar.gz files directly exported from Alma"
    exit
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    script_dir="$(dirname "$(stat -f "$0")")"
else
    script_dir="$(dirname "$(readlink -f "$0")")"
fi

input_files_dir="$1"
set_name="$2"

# full path to boundwiths.sqlite file
export BOUND_WITHS_DB_FILENAME=${BOUND_WITHS_DB_FILENAME:-$script_dir/bound_withs.sqlite3}
export BOUND_WITHS_XML_DIR="$input_files_dir/processed"

export XSL_DIR=${XSL_DIR:-$script_dir/xsl}

echo "####################"
echo "First pass: fix XML namespace and create boundwith_.*xml files"
find $input_files_dir -name '*.tar.gz' | xargs -P $NUM_INDEXING_PROCESSES -t -I FILENAME ./preprocess_step1.sh FILENAME

echo "####################"
echo "Creating boundwiths index..."

echo "Indexing the derived boundwith_*.xml files into a sqlite database"
bundle exec rake pennlib:marc:create_boundwiths_index

echo "####################"
echo "Fixing MARC and merging in boundwith holdings"
find $input_files_dir/processed -name $set_name'*.xml.gz' | xargs -P $NUM_INDEXING_PROCESSES -t -I FILENAME ./preprocess_step2.sh FILENAME
