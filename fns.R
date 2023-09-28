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
                   bins = NULL,
                   # basemap = NULL,
                   message = F,
                   labFormat = NULL) {
  if (message) message("Check if data is in EPSG:3857; if not, raster is being re-projected")

  layer_params <- read_yaml('layers.yml')

  # args_envir <- environment()
  
  # This replaces the layer_params yaml values with the function arguments, if they are not null
  # This was the intention of override_layer_params() and the commented out code below, but I was
  # having environment issues.
  params <- layer_params[[yaml_key]]
  argument_keys <- c("palette", "bins", "breaks", "center", "domain", "color_scale", "labFormat") 
  for (argument_key in argument_keys) {
    if(exists(argument_key)) {
      argument_value <- get(argument_key)
      if(!is.null(argument_value)) {
        params[[argument_key]] <- argument_value
      }
    }
  }

# lapply(
#   ls() %>% subset(!(. %in% c("data", "args_envir"))) %>% .[1:7],
#   function (argument_key) {
#     argument_value <- get(argument_key)
#     if (!is.null(argument_value)) {
#       return(argument_value)
#     } else {
#       return(layer_params[[yaml_key]][[argument_key]])
#     }
#   })
#   
#   params <- layer_params[[yaml_key]] %>%
#     # Replace layer parameters (layers.yml) with args from create_layer_function()
#     override_layer_params(yaml_key = yaml_key, args_envir = args_envir)
  
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

  # CRC Workshop's app.R's raster_discrete() uses the following variables
  # What are each of these doing and do I need to use them?
  # - map_id: this is Shiny specific and names the map
  # - input_name: used to name the layer group (my group_id)
  # - raster_var: x in addRasterImage or 
  # - raster_col: either a color scale function or a vector of colors?
  # - raster_val: for discrete rasters, legend labels; for continuous, the raster values
  #   - this is used in the color_scale with raster_col(raster_val) and as the legend labels
  #   - for the legend labels, need to match the colors in raster_col (same number)  -- it might
  #     be helpful to just use dicitonaries instead (like I do with landcover in CRC)
  # - leg_title: title for the legend
  # - lab_suffix = '' : suffix to use for the labels

  # Differences between raster_discrete and raster_continuous in app.r:
  # - raster_col can be either a function or a character vector of colors
  #   - if it is a function
  #     - raster_continuous
  #       - addLegend uses `pal` instead of `colors`
  #       - addLegend uses `values` instead of `labels` (though maybe this could be changed?)
  #     - raster_discrete
  #       - addLegend uses `colors = raster_col(raster_val)`
  #       - addLegend uses `labels = names(raster_val)`
  #   - if it is not a function (so it's a character vector of colors)

  layer_function <- function(maps, show = T) {
      if (class(data)[1] %in% c("SpatRaster", "RasterLayer")) {
      # RASTER
        maps <- maps %>% 
          addRasterImage(data, opacity = 1,
            colors = color_scale,
            # For now the group needs to match the section id in the text-column
            # group = params$title %>% str_replace_all("\\s", "-") %>% tolower(),
            group = group)
      } else if (class(data)[1] %in% c("SpatVector", "sf")) {
      # VECTOR
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
          # bins = params$bins,
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

# override_layer_params <- function(params, yaml_key, inherits = T, args_envir) {
#   # print("Made it inside override!")
#   if (!is.null(yaml_key)) { # Why am I limiting this to if yaml_key isn't null?
#   # print("and inside if!")
#         params <- lapply(
#         c("palette", "bins", "breaks", "center", "title", "domain", "color_scale", "basemap", "labFormat"),
#         function(key) {
#         # print("inside lapply!")
#         if (exists(key, envir = args_envir, inherits = inherits)) {
#           print(paste(key, "existss1"))
#           # key_value <- eval(parse(text = key))
#           key_value <- get(key, envir = args_envir)
#           if (!is.null(key_value)) params[[key]] <- key_value
#         } else {
#           # print(paste(key, "not overridden"))
#           params[[key]] <- params[[key]]}
#           return(params)
#       })
#   }
#   return(params)
# }

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
    color_scale <- colorBin(
      palette = palette,
      domain = domain,
      bins = bins,
      # Might want to turn pretty back on
      pretty = FALSE,
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

