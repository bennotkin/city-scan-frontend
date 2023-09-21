# Packages ----
library(terra)
library(sf)
library(leaflet)
library(yaml)
library(stringr)
library(mapview)
library(dplyr)

# Functions ----
# Function for reading rasters with fuzzy names
# Ideally, though, we would name in a consistent way where this is rendered unnecessary
fuzzy_read <- function(city_dir, fuzzy_string, FUN = read_raster, path = F, ...) {
  city_folder <- paste0(city_dir, "output")
  file <- list.files(city_folder) %>% subset(str_detect(., fuzzy_string)) %>%
    str_extract("^[^\\.]*") %>% unique()
  if (length(file) > 1) warning(paste("Too many", fuzzy_string, "files in", city_folder))
  if (length(file) < 1) warning(paste("No", fuzzy_string, "file in", city_folder))
  if (length(file) == 1) {
    if (!path) {
      content <- suppressMessages(FUN(city_folder, file, ...))
    } else {
      content <- suppressMessages(FUN(paste(city_folder, file, sep = "/"), ...))
    }
    return(content)
  } else {
    return(NA)
  }
}

# Read raster function 
# This is the earlier version that takes folder and then file name as the first
# two args; not sure why I did this
read_raster <- function(folder, raster_name, raster_band = NULL, ...) {
  if (!is.null(raster_band)) {
    rast(paste0(folder, '/', raster_name, '.tif'), band = raster_band, ...)
  } else {
    rast(paste0(folder, '/', raster_name, '.tif'), ...)
  }
}

# Edit this to take just a path
read_raster <- function(folder, raster_name, raster_band = NULL, ...) {
  if (!is.null(raster_band)) {
    rast(paste0(folder, '/', raster_name, '.tif'), band = raster_band, ...)
  } else {
    rast(paste0(folder, '/', raster_name, '.tif'), ...)
  }
}

# round_up_breaklist <- function(breaklist, tonum = 10) {
#   last <- -1000
#   raw = 0
#   ...
# }
# 
# reformulate_legend_labels <- function(lyr) {
#   # Add warning message if symbology type isn't RASTER_CLASSIFIED or GRAADUATED_COLORS:
#   # "WARNING: for map %s a file that is not classified raster is passed into symbology and legend updating function"
# }

# Functions for making the maps
plot_basemap <- function(basemap_style = "satellite") {
  basemap <-leaflet(
      data = aoi,
      options = leafletOptions(zoomControl = F, zoomSnap = 0.1)) %>% 
    fitBounds(lng1 = unname(aoi_bounds$xmin - (aoi_bounds$xmax - aoi_bounds$xmin)/20),
              lat1 = unname(aoi_bounds$ymin - (aoi_bounds$ymax - aoi_bounds$ymin)/20),
              lng2 = unname(aoi_bounds$xmax + (aoi_bounds$xmax - aoi_bounds$xmin)/20),
              lat2 = unname(aoi_bounds$ymax + (aoi_bounds$ymax - aoi_bounds$ymin)/20))

    { if (basemap_style == "satellite") { 
      basemap <- basemap %>% addProviderTiles(., providers$Esri.WorldImagery,
                       options = providerTileOptions(opacity = basemap_opacity))
    } else if (basemap_style == "vector") {
      # addProviderTiles(., providers$Wikimedia,
      basemap <- basemap %>% addProviderTiles(providers$CartoDB.Positron)
                       # addProviderTiles(., providers$Stadia.AlidadeSmooth,
                      #  options = providerTileOptions(opacity = basemap_opacity))
    } }
  return(basemap)
}

override_params <- function(params, yaml_key, inherits = F) {
  if (!is.null(yaml_key)) {
    c("palette", "breaks", "center", "title", "domain", "color_scale", "basemap", "labFormat") %>%
      lapply(function(key) {
        if (exists(key, inherits = inherits)) {
          key_value <- eval(parse(text = key))
          if (!is.null(key_value)) params[[key]] <- key_value
        } else {
          # print(paste(key, "not overridden"))
          params[[key]] <- params[[key]]}
      })
  }
  return(params)
}

set_domain <- function(data, domain = NULL, center = NULL) {
  if (!is.null(domain)) return(domain) else {
    # This is a very basic way to set domain. Look at toolbox for more robust layer-specific methods
    raster_values <- values(data) %>% subset(!is.na(.))
    min <- min(raster_values)
    max <- max(raster_values)
    domain <- c(min, max)
    return(domain)
  }
}

create_color_scale <- function(domain, palette, center = NULL, bins = 5, reverse = F) {
  if (bins == 0) {
    color_scale <- colorNumeric(palette = palette, domain = domain,
                                na.color = 'transparent', reverse = reverse) 
  } else {
    color_scale <- colorBin(palette = palette, domain = domain, bins = bins,
                              na.color = 'transparent', reverse = reverse)         
  }
  return(color_scale)
}

add_aoi <- function(map, data = aoi, color = 'black', weight = 3, fill = F, dashArray = '12', ...) {
  addPolygons(map, data = data, color = color, weight = weight, fill = fill, dashArray = dashArray, ...)
}

create_layer_function <- function(data,
                   yaml_key = NULL,
                   palette = NULL,
                   domain = NULL,
                   center = NULL,
                   breaks = NULL,
                   color_scale = NULL,
                   basemap = "vector",
                   message = F,
                   labFormat = NULL) {
  if (message) message("Check if data is in EPSG:3857; if not, raster is being re-projected")

  params <- layer_params[[yaml_key]] %>%
    override_params(yaml_key = yaml_key)
  
  if (is.null(params$bins)) params$bins <- 0
  if (is.null(params$labFormat)) params$labFormat <- labelFormat()

  if (is.null(color_scale)) {
    domain <- set_domain(data, domain = params$domain)
    color_scale <- create_color_scale(
      domain = domain,
      palette = params$palette,
      center = params$center,
      bins = params$bins)
  }

  layer_id <- yaml_key

  layer_function <- function(map) {
      map %>% addRasterImage(data, opacity = 1,
                    colors = color_scale,
                    group = params$title,
                    layerId = layer_id) %>%
      # See here for formatting the legend: https://stackoverflow.com/a/35803245/5009249
      addLegend('bottomright', pal = color_scale, values = c(min(values(data), na.rm = T), max(values(data), na.rm = T)), opacity = legend_opacity,
                # bins = 3,  # legend color ramp does not render if there are too many bins
                title = params$title,
                labFormat = params$labFormat,
                group = params$title)
  }

  return(layer_function)
}

# Making the static map, given the dynamic map
mapshot_styled <- function(map_dynamic, file_suffix, return) {
  mapshot(map_dynamic,
          remove_controls = c('zoomControl'),
          file = paste0(output_dir, city_string, '-', file_suffix, '.png'),
          vheight = vheight, vwidth = vwidth, useragent = useragent)
  # return(map_static)
}

