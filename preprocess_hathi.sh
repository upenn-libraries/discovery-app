#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: preprocess_hathi.sh input_files_dir"
    echo
    echo "input_files_dir is a directory where gzipped OAI XML files have been fetched and placed"
    exit
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    script_dir="$(dirname "$(stat -f "$0")")"
else
    script_dir="$(dirname "$(readlink -f "$0")")"
fi

input_files_dir="$1"
set_name="$2"

export XSL_DIR=${XSL_DIR:-$script_dir/xsl}

echo "####################"
echo "Converting OAI to MARC"
find $input_files_dir -maxdepth 1 -name '*.gz' | xargs -P $NUM_INDEXING_PROCESSES -t -I FILENAME ./preprocess_hathi_file.sh FILENAME
