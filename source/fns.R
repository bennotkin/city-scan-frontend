# Packages ----
library(terra)
library(sf)
library(leaflet)
library(yaml)
library(stringr)
# library(mapview)
library(dplyr)
library(plotly)

# Map Functions ----
# Function for reading rasters with fuzzy names
# Ideally, though, we would name in a consistent way where this is rendered unnecessary
fuzzy_read <- function(spatial_dir, fuzzy_string, FUN = rast_as_vect, path = T, ...) {
  file <- list.files(spatial_dir) %>% subset(str_detect(., fuzzy_string)) #%>%
    #str_extract("^[^\\.]*") %>% unique()
  if (length(file) > 1) warning(paste("Too many", fuzzy_string, "files in", spatial_dir))
  if (length(file) < 1) warning(paste("No", fuzzy_string, "file in", spatial_dir))
  if (length(file) == 1) {
    if (!path) {
      content <- suppressMessages(FUN(spatial_dir, file, ...))
    } else {
      file_path <- paste_path(spatial_dir, file)
      content <- suppressMessages(FUN(file_path, ...))
    }
    return(content)
  } else {
    return(NA)
  }
}

# # Read raster function 
# # This is the earlier version that takes folder and then file name as the first
# # two args; I believe I did this so it could be used with fuzzy_read
# read_raster <- function(folder, raster_name, raster_band = NULL, ...) {
#   if (!is.null(raster_band)) {
#     rast(paste0(folder, '/', raster_name, '.tif'), band = raster_band, ...)
#   } else {
#     rast(paste0(folder, '/', raster_name, '.tif'), ...)
#   }
# }

# # Edit this to take just a path
# read_raster <- function(folder, raster_name, raster_band = NULL, ...) {
#   if (!is.null(raster_band)) {
#     rast(paste0(folder, '/', raster_name, '.tif'), band = raster_band, ...)
#   } else {
#     rast(paste0(folder, '/', raster_name, '.tif'), ...)
#   }
# }

rast_as_vect <- function(filename, digits = 8, ...) as.polygons(rast(filename, ...), digits = digits)

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
plot_basemap <- function(basemap_style = "vector") {
  basemap <-leaflet(
      data = aoi,
      # Need to probably do this with javascript
      height = "calc(100vh - 2rem)",
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

create_layer_function <- function(data, yaml_key = NULL, color_scale = NULL, message = F, fuzzy_string = NULL, ...) {  
  if (message) message("Check if data is in EPSG:3857; if not, raster is being re-projected")

  # Override the layers.yaml parameters with arguments provided to ...
  # Parameters include bins, breaks, center, color_scale, domain, labFormat, and palette
  layer_params <- read_yaml('source/layers.yml')
  yaml_params <- layer_params[[yaml_key]]
  new_params <- list(...)
  kept_params <- yaml_params[!names(yaml_params) %in% names(new_params)]
  params <- c(new_params, kept_params)

  params$breaks <- unlist(params$breaks) # Necessary for some color scales
  if (is.null(params$bins)) {
    params$bins <- if(is.null(params$breaks)) 0 else length(params$breaks)
    # params$bins <- if(is.null(params$breaks)) 0 else NULL
  }
  if (is.null(params$labFormat)) params$labFormat <- labelFormat()
  # if (!is.null(params$factor) && params$factor) {
  #   params$labFormat <- function(type, levels) {return(params$labels)}
  # }

  if (!is.null(params$factor) && params$factor) {
    data <- 
      set_layer_values(
        data = data,
        values = ordered(get_layer_values(data),
                        levels = params$breaks,
                        labels = params$labels))
  }

  # data <- fuzzy_read(spatial_dir, params$fuzzy_string)
  layer_values <- get_layer_values(data)
  labels <- label_maker(x = layer_values,
                        levels = params$breaks,
                        labels = params$labels,
                        suffix = params$suffix)


  if (is.null(color_scale)) {
    domain <- set_domain(layer_values, domain = params$domain, center = params$center, factor = params$factor)
    color_scale <- create_color_scale(
      domain = domain,
      palette = params$palette,
      center = params$center,
      # bins = if (is.null(params$breaks)) params$bins else params$breaks
      bins = params$bins,
      breaks = params$breaks,
      factor = params$factor)
  }

  # CRC Workshop's app.R's raster_discrete() uses the following variables
  # What are each of these doing and do I need to use them?
  # - map_id: this is Shiny specific and names the map
  # - input_name: used to name the layer group (my group_id)
  # - raster_var: the data
  # - raster_col:
      # discrete: vector of colors, or a color scale function for land cover
      # continuous: color scale function
  # - raster_val: 
      # discrete: legend labels of provided colors
      # continuous: the raster values (think it only needs to be domain)
  
  # for discrete rasters, legend labels; for continuous, the raster values
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
  # - raster_continuous: only takes functions
  # - raster_discrete
  #   - addLegend uses colors = color_scale(legend_values)
  #   - addLegend uses labels = legend_values

### !!! I need to pull labels out because not always numeric so can't be signif

  layer_function <- function(maps, show = T) {
      if (class(data)[1] %in% c("SpatRaster", "RasterLayer")) {
      # RASTER
        maps <- maps %>% 
          addRasterImage(data, opacity = 1,
            colors = color_scale,
            # For now the group needs to match the section id in the text-column
            # group = params$title %>% str_replace_all("\\s", "-") %>% tolower(),
            group = params$group_id)
      } else if (class(data)[1] %in% c("SpatVector", "sf")) {
      # VECTOR
        maps <- maps %>%
          addPolygons(
            data = data,
            fill = if(is.null(params$fill) || params$fill) T else F,
            fillColor = ~color_scale(layer_values),
            fillOpacity = 0.9,
            stroke = if(!is.null(params$stroke) && params$stroke != F) T else F,
            color = if(!is.null(params$stroke) && params$stroke == T) ~color_scale(layer_values) else params$stroke,
            weight = params$weight,
            opacity = 0.9,
            group = params$group_id,
            # label = ~ signif(pull(data[[1]]), 6)) # Needs to at least be 4 
            label = labels)
      }
      # See here for formatting the legend: https://stackoverflow.com/a/35803245/5009249
      maps <- maps %>%
        addLegend(
          # data = data,
          position = 'bottomright',
          pal = color_scale,
          # colors = palette,
          values = domain,
          opacity = legend_opacity,
          # bins = params$bins,
          # bins = 3,  # legend color ramp does not render if there are too many bins
          # labels = params_labels,
          title = params$title,
          labFormat = params$labFormat,
          # labFormat = labelFormat(transform = function(x) label_maker(x = x, levels = params$breaks, labels = params$labels)),
          # labFormat = function(type, breaks, labels) {
          # }
          # group = params$title %>% str_replace_all("\\s", "-") %>% tolower())
          group = params$group_id)
      # if (!show) maps <- hideGroup(maps, group = layer_id)
      return(maps)
  }

  return(layer_function)
}

get_layer_values <- function(data) {
  if (class(data)[1] %in% c("SpatRaster")) {
      values <- values(data)
    } else if (class(data)[1] %in% c("SpatVector")) {
      values <- pull(values(data))
    } else if (class(data)[1] == "sf") {
      values <- data$values
    } else stop("Data is not of class SpatRaster, SpatVector or sf")
  return(values)
}

set_layer_values <- function(data, values) {
  if (class(data)[1] %in% c("SpatRaster")) {
      values(data) <- values
    } else if (class(data)[1] %in% c("SpatVector")) {
      values(data)[[1]] <- values
    } else if (class(data)[1] == "sf") {
      data$values <- values
    } else stop("Data is not of class SpatRaster, SpatVector or sf")
  return(data)
}

set_domain <- function(values, domain = NULL, center = NULL, factor = NULL) {
  if (!is.null(factor) && factor) {
    # Necessary for keeping levels in order
    domain <- ordered(levels(values), levels = levels(values))
  }
  if (is.null(domain)) {
    # This is a very basic way to set domain. Look at toolbox for more robust layer-specific methods
    min <- min(values, na.rm = T)
    max <- max(values, na.rm = T)
    domain <- c(min, max)
  }
  if (!is.null(center) && center == 0) {
    extreme <- max(abs(domain))
    domain <- c(-extreme, extreme)
  }
  return(domain)
}

create_color_scale <- function(domain, palette, center = NULL, bins = 5, reverse = F, breaks = NULL, factor = NULL) {
  # if (!is.null(breaks)) bins <- length(breaks)
  if (!is.null(factor) && factor) {
      color_scale <- colorFactor(
        palette = palette,
        domain = domain,
        levels = levels(layer_values),
        na.color = 'transparent',
        ordered = TRUE
      )
  } else if (bins == 0) {
    color_scale <- colorNumeric(
      # Why did I find it necessary to use colorRamp previously? For setting "linear"?
      # palette = colorRamp(palette, interpolate = "linear"),
      palette = palette,
      domain = domain,
      na.color = 'transparent',
      reverse = reverse) 
  } else {
    color_scale <- colorBin(
      palette = palette,
      domain = domain,
      bins = if (!is.null(breaks)) breaks else bins,
      # Might want to turn pretty back on
      pretty = FALSE,
      na.color = 'transparent', reverse = reverse)         
  }
  return(color_scale)
}

label_maker <- function(x, levels = NULL, labels = NULL, suffix = NULL) {
  # if (!is.null(labels)) {
  #   index <- sapply(x, \(.x) which(levels == .x)) # Using R's new lambda functions!
  #   x <- labels[index]
  # }
  if (!is.null(suffix)) {
    x <- paste0(x, suffix)
  }
  return(x)
  }

add_aoi <- function(map, data = aoi, color = 'black', weight = 3, fill = F, dashArray = '12', ...) {
  addPolygons(map, data = data, color = color, weight = weight, fill = fill, dashArray = dashArray, ...)
}

# Making the static map, given the dynamic map
mapshot_styled <- function(map_dynamic, file_suffix, return) {
  mapview::mapshot(map_dynamic,
          remove_controls = c('zoomControl'),
          file = paste0(styled_maps_dir, city_string, '-', file_suffix, '.png'),
          vheight = vheight, vwidth = vwidth, useragent = useragent)
  # return(map_static)
}

# Text Functions ----
read_md <- function(file) {
  md <- readLines(file)
  instruction_lines <- 1:grep("CITY CONTENT BEGINS HERE", md)
  mddf <- tibble(text = md[-instruction_lines]) %>%
    mutate(
      # Should maybe use a different header symbol than hashes so that the content itself can use hash
      # section = case_when(str_detect(text, "^## ") ~ text, T ~ NA_character_),
      # slide = case_when(str_detect(text, "^### ") ~ text, T ~ NA_character_),
      section = case_when(str_detect(text, "^//// ") ~ str_extract(text, "^/+ (.*)$", group = T), T ~ NA_character_),
      slide = case_when(str_detect(text, "^// ") ~ str_extract(text, "^/+ (.*)$", group = T), T ~ NA_character_),
      .before = 1
    ) %>% tidyr::fill(section, slide) %>%
    filter(!str_detect(text, "^/") & !str_detect(text, "^----")) %>%
    # Do I want to remove header lines? For now, yes
    filter(!str_detect(text, "^#")) %>%
    # filter(!str_detect(text, "^\\s*$")) %>%
    filter(!is.na(slide))
  text_list <- sapply(unique(mddf$section), function(sect) {
    section_df <- filter(mddf, section == sect)
    section_list <- sapply(c(unique(section_df$slide)), function(s) {
      if (s == "empty") return (NULL)
      slide_text <- filter(section_df, slide == s)$text
      # if (str_detect(slide_text[1], "^\\s*$")) {
      #   slide_text <- slide_text[-1]
      # }
      # return(list(takeaways = slide_text))
      return(list(takeaways = slide_text))
    }, simplify = F)
    return(section_list)
  }, simplify = F)
  return(text_list)
}

# merge_text_lists <- function(...) {
#   lists <- c(...)
#   keys <- unique(names(lists))
#   merged <- sapply(keys, function(k) {
#     index <- names(lists) == k
#     new_list <- c(unlist(lists[index], F, T))
#     names(new_list) <- str_extract(names(new_list), "([^\\.]+)$", group = T)
#     unique(names(new_list)) %>%
#       sapply(function (j) {
#         index2 <- names(new_list) == j
#         new_list2 <- c(unlist(new_list[index2], F, T))
#         names(new_list2) <- str_extract(names(new_list2), "([^\\.]+)$", group = T)
#         return(new_list2)
#       }, simplify = F)
#     return(new_list)
#   }, simplify = F)
#   return(merged)
# }

merge_lists <- function(x, y) {
  sections <- unique(c(names(x), names(y)))
  sapply(sections, function(sect) {
    merged_section <- c(x[[sect]], y[[sect]])
    slides <- unique(names(merged_section))
    sapply(slides, function(slide) {
      merged_slide <- c(x[[sect]][[slide]], y[[sect]][[slide]])
    }, simplify = F)
  }, simplify = F)
}

print_md <- function(x, div_class = NULL) {
  if (!is.null(div_class)) cat(":::", div_class, "\n")
  cat(x, sep = "\n")
  if (!is.null(div_class)) cat(":::")
}

print_slide_text <- function(slide) {
  if (!is.null(slide$takeaways)) {
    print_md(slide$takeaways, div_class = "takeaways")
    cat("\n")
  }
  if (!is.null(slide$method)) {
    print_md(slide$method, div_class = "method")
    cat("\n")
  }
  if (!is.null(slide$footnote)) print_md(slide$footnote, div_class = "footnote")
}
