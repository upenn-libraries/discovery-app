#!/bin/bash

if [[ "$OSTYPE" == "darwin"* ]]; then
    SCRIPT_DIR="$(dirname "$(stat -f "$0")")"
else
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
fi

# figure out the dir portion of passed-in arg
if [ -d "$1" ]; then
    INPUT_FILES_DIR="$1"
else
    INPUT_FILES_DIR=`dirname "$1"`
fi

# full path to boundwiths.sqlite file
export BOUND_WITHS_DB_FILENAME=${BOUND_WITHS_DB_FILENAME:-$SCRIPT_DIR/bound_withs.sqlite3}
export BOUND_WITHS_XML_DIR="$INPUT_FILES_DIR"

export XSL_DIR=${XSL_DIR:-$SCRIPT_DIR/xsl}

echo "First pass: fix XML namespace and create boundwith_.*xml files"
./process_files.rb -p $NUM_INDEXING_PROCESSES -s fix_namespace,create_bound_withs "$@"

echo "Indexing the derived boundwith_*.xml files into a sqlite database"
bundle exec rake pennlib:marc:create_boundwiths_index

echo "Fixing MARC and merging in boundwith holdings"
./process_files.rb -p $NUM_INDEXING_PROCESSES -i -s fix_marc,merge_bound_withs,format,rename_to_final_filename "$@"
