#!/usr/bin/env bash
set -eo pipefail

echo "Mounted to $MNT_DIR"

# Make sure the subdirectories of the mount directory exist (probably only need
# to do 03-render-output because if the others don't exist, there's no content)
mkdir -p $MNT_DIR/$CITY_DIR/01-user-input $MNT_DIR/$CITY_DIR/02-process-output $MNT_DIR/$CITY_DIR/03-render-output 

# Instead of moving the files afterward, it might make sense to have a site folder that I build from
quarto render index.qmd
cp index.qmd $MNT_DIR/$CITY_DIR/03-render-output/index.qmd
cp index.html $MNT_DIR/$CITY_DIR/03-render-output/index.html
cp -r index_files $MNT_DIR/$CITY_DIR/03-render-output/index_files