# For R & Docker primer, see http://jsta.github.io/r-docker-tutorial/

# Install R base image from Rocker (builds on Ubuntu 22.04 LTS)
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockdockeerfiles/Dockerfile_r-ver_4.0.2 
ARG R_VERSION=4.3.1
FROM rocker/r-ver:${R_VERSION}
LABEL name=pip-api \
  version=0.0.1 \
  authors="Ben Notkin" \
  maintainer="bnotkin@worldbank.org" \
  organization="World Bank Group"

# While rocker has specific images for tidyverse and geospatial, they are not arm64 compatible
RUN /rocker_scripts/install_tidyverse.sh
RUN /rocker_scripts/install_geospatial.sh
RUN /rocker_scripts/install_python.sh
RUN /rocker_scripts/install_pandoc.sh
RUN /rocker_scripts/install_jupyter.sh
RUN /rocker_scripts/install_quarto.sh


RUN install2.r \
    quarto \
    plotly

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

WORKDIR /home
COPY fns.R fns.R
COPY index.qmd index.qmd
COPY inputs-form.qmd inputs-form.qmd
COPY layers.yml layers.yml
COPY city_inputs.yml city_inputs.yml
COPY scrollytelling.qmd scrollytelling.qmd
COPY custom.scss custom.scss
COPY text-files text-files
COPY images images
COPY cities cities
COPY plots plots

RUN mkdir mount

CMD ["bash"]

# Docker commands to build and run Docker image
# docker build -t nalgene .
# docker run -it --rm -v "$(pwd)"/mount:/home/mount nalgene