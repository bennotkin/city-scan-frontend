#!/usr/bin/env bash
set -eo pipefail

echo "Mounting GCS Fuse."
# Mount the bucket: for alternate arguments see https://github.com/GoogleCloudPlatform/gcsfuse/blob/master/docs/semantics.md
# I am using --implicit-dirs, for better or for worse. See, and fix, commented code for other option. This is necessary because
# of Cloud Storage's "flat hierarchy"
gcsfuse --debug_gcs --debug_fuse --implicit-dirs $BUCKET $MNT_DIR
echo "Mounting completed: $BUCKET to $MNT_DIR"

# # See "Using --implicit-dirs" at https://github.com/GoogleCloudPlatform/gcsfuse/blob/master/docs/semantics.md#files-and-directories
# # Could use the --implicit-dirs arg but for now choosing to follow advice of last line in section, and write all of the directories
# # Unfortunately this is erring with 
# cd $MNT_DIR
# gcloud storage ls --project=$PROJECT -R gs://$BUCKET | grep "/:$" | tr -d ":" | xargs mkdir -p
# cd /home

# Make sure the subdirectories of the mount directory exist (probably only need
# to do 03-render-output because if the others don't exist, there's no content)
mkdir -p $MNT_DIR/$CITY_DIR/01-user-input $MNT_DIR/$CITY_DIR/02-process-output $MNT_DIR/$CITY_DIR/03-render-output 

# For understanding the mount directory relationship
echo "CITY_DIR is..."
cat city-dir.txt
echo "Mount ($MNT_DIR) contents are..."
ls -R $MNT_DIR

# Instead of moving the files afterward, it might make sense to have a site folder that I build from
quarto render index.qmd
cp index.qmd $MNT_DIR/$CITY_DIR/03-render-output/index.qmd
cp index.html $MNT_DIR/$CITY_DIR/03-render-output/index.html
cp -r index_files $MNT_DIR/$CITY_DIR/03-render-output/index_files