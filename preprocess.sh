#!/bin/bash

if [[ "$OSTYPE" == "darwin"* ]]; then
    SCRIPT_DIR="$(dirname "$(stat -f "$0")")"
else
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
fi

XSL_DIR=${XSL_DIR:-$SCRIPT_DIR/xsl}

# figure out the dir portion of passed-in glob
dir=`dirname "$1"`
GLOB_DIR=${GLOB_DIR:-$dir}

# first pass: fix XML namespace and create boundwith_.*xml files
time ./process_files.rb -x $XSL_DIR -p 4 -i -s fix_namespace,create_bound_withs "$@"

# index the derived boundwith_*.xml files into a sqlite database
time bundle exec rake pennlib:marc:create_boundwiths_index BOUND_WITHS_DB_FILENAME=bound_withs.sqlite3 BOUND_WITHS_GLOB="$GLOB_DIR/boundwiths_*.xml"

# fix up the MARC and merge in the boundwith holdings
time ./process_files.rb -x $XSL_DIR -p 4 -i -s fix_marc,merge_bound_withs,format,rename_to_final_filename "$@"
