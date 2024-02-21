# For R & Docker primer, see http://jsta.github.io/r-docker-tutorial/

# Install R base image from Rocker (builds on Ubuntu 22.04 LTS)
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockdockeerfiles/Dockerfile_r-ver_4.0.2 
ARG R_VERSION=4.3.2
FROM rocker/r-ver:${R_VERSION}
LABEL name=nalgene \
  authors="Ben Notkin" \
  maintainer="bnotkin@worldbank.org" \
  organization="World Bank Group" \
  description="Renders City Resilience Program City Scans"

# While rocker has specific images for tidyverse and geospatial, they are not arm64 compatible
RUN /rocker_scripts/install_tidyverse.sh
RUN /rocker_scripts/install_geospatial.sh
RUN /rocker_scripts/install_python.sh
RUN /rocker_scripts/install_pandoc.sh
RUN /rocker_scripts/install_jupyter.sh
RUN /rocker_scripts/install_quarto.sh

## R's X11 runtime dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libx11-6 \
    libxss1 \
    libxt6 \
    libxext6 \
    libsm6 \
    libice6 \
    xdg-utils \
  && rm -rf /var/lib/apt/lists/*

# Google Cloud Storage FUSE
# Taken from https://cloud.google.com/run/docs/tutorials/network-filesystems-fuse#cloudrun_fs_dockerfile-nodejs
# except https instead of http, per $kojima-takeo's finding at https://github.com/GoogleCloudPlatform/gcsfuse/issues/1424
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    tini && \
    echo "deb https://packages.cloud.google.com/apt gcsfuse-buster main" > /etc/apt/sources.list.d/gcsfuse.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y gcsfuse && \
    apt-get clean

# Install remaining R packages
RUN install2.r \
    quarto \
    plotly

# Set fallback mount directory
ENV MNT_DIR /home/mnt

# Copy local code to the container image.
# Consider both cloning from Github & moving this all to a mounted drive instead
WORKDIR /home
COPY . ./

# Ensure the scripts are executable
# For Google Gloud
RUN chmod +x /home/scripts/gcsfuse_run.sh
# For local runs
RUN chmod +x /home/scripts/local_run.sh

# Create mount directory for job
RUN mkdir -p $MNT_DIR

# Write environment variable CITY_DIR to TXT file for use by R
RUN $CITY_DIR >> city-dir.txt

# Use tini to manage zombie processes and signal forwarding
# https://github.com/krallin/tini
ENTRYPOINT ["/usr/bin/tini", "--"] 

# Pass the startup script as arguments to Tini
CMD ["/home/scripts/gcsfuse_run.sh"]

#### Docker commands to build and run Docker image locally ####################

# Build the container
# docker build -t nalgene .
# Run the container without rendering the site ()
# docker run -it --rm -v "$(pwd)"/mnt:/home/mnt -e CITY_DIR=$CITY_DIR nalgene bash
# Run the container with rendering the site
# docker run -it --rm -v "$(pwd)"/mnt:/home/mnt -e CITY_DIR=$CITY_DIR nalgene scripts/local_run.sh
# where $CITY_DIR is the city-specific directory in mnt/ (e.g., 2023-10-kenya-mombasa/)

# Alternatively, instead of building the container, you can run the version
# of the image hosted on Docker Hub by simply replacing `nalgene` with 
# `notkin/nalgene` in the command. !! This will not include any edits you've
# made to non-mounted files !!

# You can avail yourself of VS Code's functionality (instead of limiting
# yourself to the command line), with the Dev Containers extension (see tutorial
# at https://code.visualstudio.com/docs/devcontainers/containers
# 1. Install Dev Containers extension
# 2. Run the container: `docker run -it --rm -v "$(pwd)"/mnt:/home/mnt -e CITY_DIR=$CITY_DIR nalgene bash`
# 3. Attach VS Code to the container: CMD/CTRL + SHIFT + P, then type/select
#    "Dev Containers: Attach to Running Container..."; hit Enter again to select
#    oddly named container
# 4. Change directory to /home: cd ../home
# 5. In VS Code's Explorer, click Open Folder, type /home, and hit enter