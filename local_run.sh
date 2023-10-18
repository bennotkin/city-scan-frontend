#!/usr/bin/env bash
set -eo pipefail

echo "Mounted to $MNT_DIR"

mkdir -p $MNT_DIR/input
mkdir -p $MNT_DIR/output

# Instead of moving the files afterward, it might make sense to have a site folder that I build from
quarto render index.qmd
cp index.qmd $MNT_DIR/output/index.qmd
cp index.html $MNT_DIR/output/index.html
cp -r index_files $MNT_DIR/output/index_files
