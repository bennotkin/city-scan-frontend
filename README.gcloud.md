# Using Google Cloud


## Commands for setting up mounted cloud run storage
Taken from https://cloud.google.com/run/docs/tutorials/network-filesystems-fuse#cloudrun_fs_dockerfile-python

```sh
gsutil mb -l us-central1 gs://crp-city-scan-text-bucket
gcloud iam service-accounts create fs-identity

gcloud projects add-iam-policy-binding city-scan-gee-test \
     --member "serviceAccount:fs-identity@city-scan-gee-test.iam.gserviceaccount.com" \
     --role "roles/storage.objectAdmin"

# Note that this builds from source, without a cache

# gcloud run deploy filesystem-app --source . \
#     --execution-environment gen2 \
#     --allow-unauthenticated \
#     --service-account fs-identity \
#     --update-env-vars BUCKET=crp-city-scan-text-bucket

# To build with a cache, use cloudbuild.yaml

gcloud builds submit --config cloudbuild.yaml
```


## Commands for creating and executing a job
Taken from https://cloud.google.com/run/docs/create-jobs#command-line_1

```sh
gcloud run jobs create job-the-first \
  --image us-central1-docker.pkg.dev/city-scan-gee-test/cloud-run-source-deploy/filesystem-app:latest \
  --max-retries 0 \
  --task-timeout 20m

# The default memory of 512 MiB is insufficient; how do I know how much is necessary?
gcloud run jobs update job-the-first \
  --update-env-vars BUCKET=crp-city-scan-text-bucket
  --memory 2Gi

# See same URL for updating a job

gcloud run jobs execute job-the-first
```