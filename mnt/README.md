For local runs, use this directory as the mount directory

It is the equivalent of the bucket on Google Cloud Storage

This directory should include a directory for the city in the format of `YYYY-MM-country-city`, which in turn has three subdirectories:

- `YYYY-MM-country-city/` (e.g., `2023-10-kenya-mombasa`)
  - `01-user-input/` for files uploaded by user
    - `AOI/`
    - `city_inputs.yaml`
  - `02-process-output/` for files generated in raster processing
    - `spatial/` for the TIFs and other files used for mapmaking
    - `stats/` 
  - `03-render-output/` for files generated in site rendering