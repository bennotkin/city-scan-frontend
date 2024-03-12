# All the mid-level processing that needs to happen before rendering

# Move all remaining "mid" processing to this file so that the chunks for each
# layer in index.qmd can be auto generated using menu.yml or equivalent

# This should maybe live in backend (as should much of this file)
# Should this be a set of higher-level functions instead?
# I also have begun drafting this into python: pre-render/write-population.py
source("pre-render/write-population.R")

# Generate plots
source('pre-render/plots.R')