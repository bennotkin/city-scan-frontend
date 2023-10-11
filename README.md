# Building a City Scan

This directory builds a City Scan from city-specific data, using a Docker container.

## Instructions
1. Edit `city_inputs.yml` to have city relevant parameters
2. Add the appropriate data to `cities/`
3. Build the Docker container with `docker build -f Dockerfile nalgene .`
4. Run the container with a bind-mount: `docker run -it --rm "$(pwd)/mount:/home/mount`
5. Inside the container, run `quarto render index.qmd` to build the site
6. Copy the rendered site into the mounted directory: `cp index.html mount/index.html && cp -r index_files mount/index_files`

## Docker Container
