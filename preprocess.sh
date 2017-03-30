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

# first pass: fix XML namespace and create boundwith_.*xml files
time ./process_files.rb -p 4 -s fix_namespace,create_bound_withs "$@"

# index the derived boundwith_*.xml files into a sqlite database
time bundle exec rake pennlib:marc:create_boundwiths_index

# fix up the MARC and merge in the boundwith holdings
time ./process_files.rb -p 4 -i -s fix_marc,merge_bound_withs,format,rename_to_final_filename "$@"
