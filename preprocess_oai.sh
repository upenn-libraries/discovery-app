#!/bin/bash

XSL_DIR=${XSL_DIR:-/home/jeffchiu/blacklight_dev/xsl}

# figure out the dir portion of passed-in glob
dir=`dirname "$1"`
GLOB_DIR=${GLOB_DIR:-$dir}

# first pass: convert OAI to MARC and create boundwith_.*xml files
time ./process_files.rb -x $XSL_DIR -p 4 -s convert_oai_to_marc,create_bound_withs "$@"

# index the derived boundwith_*.xml files into a sqlite database
time bundle exec rake pennlib:marc:create_boundwiths_index BOUND_WITHS_DB_FILENAME=bound_withs.sqlite3 BOUND_WITHS_GLOB="$GLOB_DIR/boundwiths_*.xml"

# fix up the MARC and merge in the boundwith holdings; note that we use -a to delete the *_marc.xml 'originals' in this pipline
time ./process_files.rb -a -x $XSL_DIR -p 4 -s fix_marc,merge_bound_withs,format,rename_to_final_filename "$@"
