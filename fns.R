# Packages ----
library(terra)
library(sf)
library(leaflet)
library(yaml)
library(stringr)
# library(mapview)
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
# two args; I believe I did this so it could be used with fuzzy_read
read_raster <- function(folder, raster_name, raster_band = NULL, ...) {
  if (!is.null(raster_band)) {
    rast(paste0(folder, '/', raster_name, '.tif'), band = raster_band, ...)
  } else {
    rast(paste0(folder, '/', raster_name, '.tif'), ...)
  }
}

# # Edit this to take just a path
# read_raster <- function(folder, raster_name, raster_band = NULL, ...) {
#   if (!is.null(raster_band)) {
#     rast(paste0(folder, '/', raster_name, '.tif'), band = raster_band, ...)
#   } else {
#     rast(paste0(folder, '/', raster_name, '.tif'), ...)
#   }
# }

# round_up_breaklist <- function(breaklist, tonum = 10) {
#   last <- -1000
#   raw = 0
#   ...
# }
# 
# reformulate_legend_labels <- function(lyr) {
#   # Add warning message if symbology type isn't RASTER_CLASSIFIED or GRADUATED_COLORS:
#   # "WARNING: for map %s a file that is not classified raster is passed into symbology and legend updating function"
# }

# Functions for making the maps
plot_basemap <- function(basemap_style = "satellite") {
  basemap <-leaflet(
      data = aoi,
      # Need to probably do this with javascript
      height = "100vh",
      width = "100%",
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

  layer_params <- read_yaml('layers.yml')

  params <- layer_params[[yaml_key]] %>%
    # Replace layer parameters (layers.yml) with args from create_layer_function()
    override_layer_params(yaml_key = yaml_key)
  
  if (is.null(params$bins)) params$bins <- 0
  if (is.null(params$labFormat)) params$labFormat <- labelFormat()

  layer_values <- get_layer_values(data)

  if (is.null(color_scale)) {
    domain <- set_domain(layer_values, domain = params$domain, center = params$center)
    color_scale <- create_color_scale(
      domain = domain,
      palette = params$palette,
      center = params$center,
      bins = params$bins)
  }

  group <- params$group_id

  layer_function <- function(maps, show = T) {
      if (class(data)[1] %in% c("SpatRaster", "RasterLayer")) {
        maps <- maps %>% 
          addRasterImage(data, opacity = 1,
            colors = color_scale,
            # For now the group needs to match the section id in the text-column
            # group = params$title %>% str_replace_all("\\s", "-") %>% tolower(),
            group = group)
      } else if (class(data)[1] %in% c("SpatVector", "sf")) {
        maps <- maps %>%
          addPolygons(
            data = data,
            fillColor = ~color_scale(values),
            fillOpacity = 0.9,
            stroke = F,
            group = group,
            label = ~ values)
      }
      # See here for formatting the legend: https://stackoverflow.com/a/35803245/5009249
      maps <- maps %>%
        addLegend('bottomright', pal = color_scale,
          values = domain,
          opacity = legend_opacity,
          # bins = 3,  # legend color ramp does not render if there are too many bins
          title = params$title,
          labFormat = params$labFormat,
          # group = params$title %>% str_replace_all("\\s", "-") %>% tolower())
          group = group)
      # if (!show) maps <- hideGroup(maps, group = layer_id)
      return(maps)
  }

  return(layer_function)
}

override_layer_params <- function(params, yaml_key, inherits = F) {
  if (!is.null(yaml_key)) { # Why am I limiting this to if yaml_key isn't null?
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

get_layer_values <- function(data) {
  if (class(data)[1] %in% c("SpatRaster", "SpatVector")) {
      values <- values(data)
    } else if (class(data)[1] == "sf") {
      values <- data$values
    } else stop("Data is not of class SpatRaster, SpatVector or sf")
  return(values)
}

set_domain <- function(values, domain = NULL, center = NULL) {
  if (is.null(domain)) {
    # This is a very basic way to set domain. Look at toolbox for more robust layer-specific methods
    min <- min(values, na.rm = T)
    max <- max(values, na.rm = T)
    domain <- c(min, max)
  }
  if (!is.null(center)) if (center == 0) {
    extreme <- max(abs(domain))
    domain <- c(-extreme, extreme)
  }
  return(domain)
}

create_color_scale <- function(domain, palette, center = NULL, bins = 5, reverse = F) {
  if (bins == 0) {
    color_scale <- colorNumeric(
      palette = colorRamp(palette, interpolate = "linear"),
      domain = domain,
      na.color = 'transparent',
      reverse = reverse) 
  } else {
    color_scale <- colorBin(palette = palette, domain = domain, bins = bins,
                              na.color = 'transparent', reverse = reverse)         
  }
  return(color_scale)
}

add_aoi <- function(map, data = aoi, color = 'black', weight = 3, fill = F, dashArray = '12', ...) {
  addPolygons(map, data = data, color = color, weight = weight, fill = fill, dashArray = dashArray, ...)
}

# Making the static map, given the dynamic map
mapshot_styled <- function(map_dynamic, file_suffix, return) {
  mapshot(map_dynamic,
          remove_controls = c('zoomControl'),
          file = paste0(output_dir, city_string, '-', file_suffix, '.png'),
          vheight = vheight, vwidth = vwidth, useragent = useragent)
  # return(map_static)
}

