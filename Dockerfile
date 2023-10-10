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
    rmarkdown \
    knitr \
    quarto \
    terra \
    sf \
    leaflet \
    yaml \
    stringr \
    dplyr

RUN install2.r \
    plotly

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

CMD ["bash"]
