# Packages ----
# Install packages from CRAN using librarian
if (!"librarian" %in% installed.packages()) install.packages("librarian")
librarian::shelf(
  terra, 
  sf, 
  leaflet, 
  yaml, 
  stringr, 
  dplyr, 
  ggplot2, # 3.5 or higher
  plotly, 
  ggspatial, 
  tidyterra, 
  cowplot, 
  glue, 
  purrr, 
  readr)

librarian::stock(
  ggnewscale # 4.10 or higher
)

# Map Functions ----
# Function for reading rasters with fuzzy names
# Ideally, though, we would name in a consistent way where this is rendered unnecessary
fuzzy_read <- function(dir, fuzzy_string, FUN = NULL, path = T, convert_to_vect = F, ...) {
  file <- list.files(dir) %>% str_subset(fuzzy_string) #%>%
    #str_extract("^[^\\.]*") %>% unique()
  if (length(file) > 1) warning(paste("Too many", fuzzy_string, "files in", dir))
  if (length(file) < 1) {
    file <- list.files(dir, recursive = T) %>% str_subset(fuzzy_string)
    if (length(file) > 1) warning(paste("Too many", fuzzy_string, "files in", dir))
    if (length(file) < 1) warning(paste("No", fuzzy_string, "file in", dir))
  }
  if (length(file) == 1) {
    if (is.null(FUN)) {
      # print(tolower(str_sub(file, -4, -1)) == ".tif")
      FUN <- if (tolower(str_sub(file, -4, -1)) == ".tif") rast else vect
    }
    if (!path) {
      content <- suppressMessages(FUN(dir, file, ...))
    } else {
      file_path <- file.path(dir, file)
      content <- suppressMessages(FUN(file_path, ...))
    }
    if (convert_to_vect && class(content)[1] %in% c("SpatRaster", "RasterLayer")) {
      content <- rast_as_vect(content)
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

rast_as_vect <- function(x, digits = 8, ...) {  
  if (class(x) == "SpatVector") return(x)
  if (is.character(x)) x <- rast(x, ...)
  out <- as.polygons(x, digits = digits)
  return(out)
}

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
  basemap <-
    leaflet(
      data = aoi,
      # Need to probably do this with javascript
      height = "calc(100vh - 2rem)",
      width = "100%",
      options = leafletOptions(zoomControl = F, zoomSnap = 0.1)) %>% 
    fitBounds(
      lng1 = unname(aoi_bounds$xmin - (aoi_bounds$xmax - aoi_bounds$xmin)/20),
              lat1 = unname(aoi_bounds$ymin - (aoi_bounds$ymax - aoi_bounds$ymin)/20),
              lng2 = unname(aoi_bounds$xmax + (aoi_bounds$xmax - aoi_bounds$xmin)/20),
              lat2 = unname(aoi_bounds$ymax + (aoi_bounds$ymax - aoi_bounds$ymin)/20))
  if (basemap_style == "satellite") { 
      basemap <- basemap %>% addProviderTiles(., providers$Esri.WorldImagery,
                       options = providerTileOptions(opacity = basemap_opacity))
    } else if (basemap_style == "vector") {
      # addProviderTiles(., providers$Wikimedia,
    basemap <- basemap %>%
      addProviderTiles(providers$CartoDB.Positron)
                       # addProviderTiles(., providers$Stadia.AlidadeSmooth,
                      #  options = providerTileOptions(opacity = basemap_opacity))
  }
  return(basemap)
}

prepare_parameters <- function(yaml_key, ...) {
  # Override the layers.yaml parameters with arguments provided to ...
  # Parameters include bins, breaks, center, color_scale, domain, labFormat, and palette
  layer_params <- read_yaml(layer_params_file)
  if (yaml_key %ni% names(layer_params)) stop(paste(yaml_key, "is not a key in source/layers.yml"))
  yaml_params <- layer_params[[yaml_key]]
  new_params <- list(...)
  kept_params <- yaml_params[!names(yaml_params) %in% names(new_params)]
  params <- c(new_params, kept_params)

  params$breaks <- unlist(params$breaks) # Necessary for some color scales
  if (is.null(params$bins)) {
    params$bins <- if(is.null(params$breaks)) 0 else length(params$breaks)
    # params$bins <- if(is.null(params$breaks)) 0 else NULL
  }
  # if (is.null(params$labFormat)) params$labFormat <- labelFormat()
  if (is.null(params$stroke)) params$stroke <- NA
  # if (!is.null(params$factor) && params$factor) {
  #   params$labFormat <- function(type, levels) {return(params$labels)}
  # }

  # Apply layer transparency to palette
  params$palette <- sapply(params$palette, \(p) {
    # If palette has no alpha, add
    if (nchar(p) == 7 | substr(p, 1, 1) != "#") return(scales::alpha(p, layer_alpha))
    # If palette already has alpha, multiply
    if (nchar(p) == 9) {
      alpha_hex <- as.hexmode(substr(p, 8, 9))
      new_alpha_hex <- as.character(alpha_hex * layer_alpha)
      if (nchar(new_alpha_hex) == 1) new_alpha_hex <- paste0(0, new_alpha_hex)
      new_p <- paste0(substr(p, 1, 7), new_alpha_hex)
      return(new_p)
    }
    warning(paste("Palette value", p, "is not of length 6 or 8"))
  }, USE.NAMES = F)

  return(params)
}

create_layer_function <- function(data, yaml_key = NULL, params = NULL, color_scale = NULL, message = F, fuzzy_string = NULL, ...) {  
  if (message) message("Check if data is in EPSG:3857; if not, raster is being re-projected")

  if (is.null(params)) {
    params <- prepare_parameters(yaml_key, ...)
  }

  if (!is.null(params$data_variable)) data <- data[params$data_variable]

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
  if(params$bins > 0 && is.null(params$breaks)) {
    params$breaks <- break_pretty2(
                data = layer_values, n = params$bins + 1, FUN = signif,
                method = params$breaks_method %>% {if(is.null(.)) "quantile" else .})
  }

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
      factor = params$factor,
      levels = levels(layer_values))
  }

# I have moved the formerly-present note on lessons from the CRC Workshop code to my `Week of 2023-11-26` note in Obsidian.

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
        if ( # Add circle markers if geometry type is "points"
          (class(data)[1] == "SpatVector" && geomtype(data) == "points") |
          (class(data)[1] == "sf" && "POINTS" %in% st_geometry_type(data))) {
          maps <- maps %>%
            addCircles(
              data = data,
              color = params$palette,
              weight = params$weight,
              # opacity = 0.9,
              group = params$group_id,
              # label = ~ signif(pull(data[[1]]), 6)) # Needs to at least be 4 
              label = labels)
        } else { # Otherwise, draw the geometries
          maps <- maps %>%
            addPolygons(
              data = data,
              fill = if(is.null(params$fill) || params$fill) T else F,
              fillColor = ~color_scale(layer_values),
              fillOpacity = 0.9,
              stroke = if(!is.null(params$stroke) && !is.na(params$stroke) && params$stroke != F) T else F,
              color = if(!is.null(params$stroke) && !is.na(params$stroke) && params$stroke == T) ~color_scale(layer_values) else params$stroke,
              weight = params$weight,
              opacity = 0.9,
              group = params$group_id,
              # label = ~ signif(pull(data[[1]]), 6)) # Needs to at least be 4 
              label = labels)
      }} else {
        stop("Data is not spatRaster, RasterLayer, spatVector or sf")
      }
      # See here for formatting the legend: https://stackoverflow.com/a/35803245/5009249
      legend_args <- list(
        map = maps,
        # data = data,
        position = 'bottomright',
        values = domain,
        # values = if (is.null(params$breaks)) domain else params$breaks,
        # pal = if (is.null(params$labels) | is.null(params$breaks)) color_scale else NULL,
        pal = if (diff(lengths(list(params$labels, params$breaks))) == 1) NULL else color_scale,
        # colors = if (is.null(params$labels) | is.null(params$breaks)) NULL else if (diff(lengths(list(params$labels, params$breaks))) == 1) color_scale(head(params$breaks, -1)) else color_scale(params$breaks),
        colors = if (diff(lengths(list(params$labels, params$breaks))) == 1) color_scale(head(params$breaks, -1)) else NULL,
        opacity = legend_opacity,
        # bins = params$bins,
        # bins = 3,  # legend color ramp does not render if there are too many bins
        labels = params$labels,
        title = params$title,
        # labFormat = params$labFormat,
        # labFormat = labelFormat(transform = function(x) label_maker(x = x, levels = params$breaks, labels = params$labels)),
        # labFormat = function(type, breaks, labels) {
        # }
        # group = params$title %>% str_replace_all("\\s", "-") %>% tolower())
        group = params$group_id)
      legend_args <- Filter(Negate(is.null), legend_args)
      # Using do.call so I can conditionally include args (i.e., pal and colors)
      maps <- do.call(addLegend, legend_args)
      # if (!show) maps <- hideGroup(maps, group = layer_id)
      return(maps)
  }

  return(layer_function)
}

create_static_layer <- function(data, yaml_key = NULL, params = NULL, ...) {
  if (is.null(params)) {
    params <- prepare_parameters(yaml_key, ...)
  }

  if (!is.null(params$data_variable)) data <- data[params$data_variable]

  if (!is.null(params$factor) && params$factor) {
    data <- 
      set_layer_values(
        data = data,
        values = ordered(get_layer_values(data),
                        levels = params$breaks,
                        labels = params$labels))
    params$palette <- setNames(params$palette, params$labels)
  }
  layer_values <- get_layer_values(data)
  palette <- params$palette
  stroke_variable <- if (length(params$stroke) > 1) params$stroke$variable else NULL
  weight_variable <- if (length(params$weight) > 1) params$weight$variable else NULL

  geom <-
    if (class(data)[1] == "SpatVector") {
      if (geomtype(data) == "points") {
        geom_spatvector(data = data, color = palette, size = 1)
      } else if (geomtype(data) == "polygons") {
        geom_spatvector(data = data, aes(fill = layer_values), color = params$stroke)
      } else if (geomtype(data) == "lines") {
        # I could use aes_list in a safer way
        # aes_list2 <- c(
        #   aes(color = .data[[stroke_variable]]))
        #   aes(linewidth = (.data[[weight_variable]])))
        aes_list <- aes(color = .data[[stroke_variable]], linewidth = (.data[[weight_variable]]))
        if (is.null(weight_variable)) aes_list <- aes_list[-2]
        if (is.null(stroke_variable)) aes_list <- aes_list[-1]
        geom_spatvector(data = data, aes_list)
      } else {
        stop(paste(yaml_key, "data is a SpatVector but not of type 'points' or 'polygons'"))
      }
    } else if (class(data)[1] == "SpatRaster") {
      geom_spatraster(data = data)
    } else {
      stop(paste(yaml_key, "data is neither SpatVector nor SpatRaster"))
    }

  title_broken <- str_replace_all(params$title, "(.{20}[^\\s]*)\\s", "\\1<br>")
  subtitle_broken <- str_replace_all(params$subtitle, "(.{20}[^\\s]*)\\s", "\\1<br>")
  title <- paste0(title_broken, "<br><br><em>", subtitle_broken, "</em>")

  if(params$bins > 0 && is.null(params$breaks)) {
    params$breaks <- break_pretty2(
                data = layer_values, n = params$bins + 1, FUN = signif,
                method = params$breaks_method %>% {if(is.null(.)) "quantile" else .})
  }

  fill_scale <- if (length(palette) == 0) NULL else {
        if (!is.null(params$factor) && params$factor) {
      # Switched to na.translate = F because na.value = "transparent" includes
      # NA in legend for forest. Haven't tried with non-raster.
      scale_fill_manual(values = palette, na.translate = F, name = title)
        } else if (params$bins == 0) {
            scale_fill_gradientn(
              colors = palette,
          limits = if (is.null(params$domain)) NULL else params$domain,
              rescaler = if (!is.null(params$center)) ~ scales::rescale_mid(.x, mid = params$center) else scales::rescale,
              na.value = "transparent",
              name = title)
          # }
        } else if (params$bins > 0) {
            scale_fill_stepsn(
              colors = palette,
              # Length of labels is one less than breaks when we want a discrete legend
              breaks = if (is.null(params$breaks)) waiver() else if (diff(lengths(list(params$labels, params$breaks))) == 1) params$breaks[-1] else params$breaks,
          # breaks_midpoints() is important for getting the legend colors to match the specified colors
              values = if (is.null(params$breaks)) NULL else breaks_midpoints(params$breaks, rescaler = if (!is.null(params$center)) scales::rescale_mid else scales::rescale, mid = params$center),
              labels = if (is.null(params$labels)) waiver() else params$labels,
              limits = if (is.null(params$breaks)) NULL else range(params$breaks),
              rescaler = if (!is.null(params$center)) ~ scales::rescale_mid(.x, mid = params$center) else scales::rescale,
              na.value = "transparent",
              oob = scales::oob_squish,
              name = title,
          guide = if (diff(lengths(list(params$labels, params$breaks))) == 1) "legend" else "colorsteps"
          )
    }
  }

  color_scale <- if (length(params$stroke) < 2 || is.null(params$stroke$palette)) {
    NULL
  } else {
    scale_color_stepsn(colors = params$stroke$palette)
  }
  linewidth_scale <- if (length(params$weight) < 2 || is.null(params$weight$range)) {
    NULL
  } else {
    scale_linewidth(range = c(params$weight$range[[1]], params$weight$range[[2]]))
  }

  scales <- list(fill_scale, color_scale, linewidth_scale) %>% .[lengths(.) > 1]

  legend_text_alignment <- if (
      !is.null(params$labels) && is.character(params$labels)
      | is.character(layer_values)) 0 else 1

  theme <- theme(
    legend.title = ggtext::element_markdown(),
    legend.text = element_text(hjust = legend_text_alignment))

  return(list(geom = geom, scale = scales, theme = theme))
}

plot_static <- function(data, yaml_key, filename = NULL, baseplot = NULL, plot_aoi = T, aoi_only = F, ...) {
  if (aoi_only) {
    layer <- NULL
  } else { 
  params <- prepare_parameters(yaml_key = yaml_key, ...)
  layer <- create_static_layer(data, params = params)
  }
  # baseplot <- if (is.null(baseplot)) ggplot() + tiles else baseplot + ggnewscale::new_scale_fill()
  # This  method sets the plot CRS to 4326, but this requires reprojecting the tiles
  ## I am now returning the CRS to 3857. I don't think this is a global fix, because it causes reprojections of the rasters
  baseplot <- if (is.null(baseplot)) {
    ggplot() +
        geom_sf(data = static_map_bounds, fill = NA, color = NA) +
        coord_sf(expand = F) +
      tiles 
  } else { baseplot + ggnewscale::new_scale_fill() }
  p <- baseplot +
        layer + 
        annotation_north_arrow(style = north_arrow_minimal, location = "br", height = unit(1, "cm")) +
        annotation_scale(style = "ticks", aes(unit_category = "metric", width_hint = 0.33), height = unit(0.25, "cm")) +        
        theme(
          # legend.key = element_rect(fill = "#FAFAF8"),
          legend.justification = c("left", "bottom"),
          legend.box.margin = margin(0, 0, 0, 12, unit = "pt"),
          legend.margin = margin(4,0,4,0, unit = "pt"),
          axis.text = element_blank(),
          axis.ticks = element_blank(),
          axis.ticks.length = unit(0, "pt"),
          plot.margin = margin(0,0,0,0))
  if (plot_aoi) p <- p + geom_sf(data = aoi, fill = NA, linetype = "dashed", linewidth = .5) #+ 
  # # There may be issues caused by this, but excluding this causes the tiles to be reprojected, which can cause darkening
  bbox_3857 <- st_bbox(st_transform(static_map_bounds, crs = "epsg:3857"))
  p <- p + coord_sf(
              crs = "epsg:3857",
          expand = F,
              xlim = bbox_3857[c(1,3)],
              ylim = bbox_3857[c(2,4)])
  if (!is.null(filename)) save_plot(filename = filename, plot = p, directory = styled_maps_dir)
  return(p)
}

save_plot <- function(plot = NULL, filename, directory, rel_widths = c(3, 1)) {
  # Saves plots with set legend widths
  plot_layout <- plot_grid(
    plot + theme(legend.position = "none"),
    # Before ggplot2 3.5 was get_legend(plot); still works but with warning;
    # there are now multiple guide-boxes
    get_plot_component(plot, "guide-box-right"),
    rel_widths = rel_widths,
    nrow = 1
  )
  
  cowplot::save_plot(
  plot = plot_layout,
  filename = file.path(directory, filename),
  base_height = map_height, base_width = sum(rel_widths)/rel_widths[1] * map_width
  )
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

create_color_scale <- function(domain, palette, center = NULL, bins = 5, reverse = F, breaks = NULL, factor = NULL, levels = NULL) {
  # List of shared arguments
  args <- list(
    palette = palette,
    domain = domain,
    na.color = 'transparent',
    alpha = T)
  # if (!is.null(breaks)) bins <- length(breaks)
  if (!is.null(factor) && factor) {
      color_scale <- rlang::inject(colorFactor(
        !!!args,
        levels = levels,
        ordered = TRUE))
  } else if (bins == 0) {
    color_scale <- rlang::inject(colorNumeric(
      # Why did I find it necessary to use colorRamp previously? For setting "linear"?
      # palette = colorRamp(palette, interpolate = "linear"),
      !!!args,
      reverse = reverse)) 
  } else {
    color_scale <- rlang::inject(colorBin(
      !!!args,
      bins = if (!is.null(breaks)) breaks else bins,
      # Might want to turn pretty back on
      pretty = FALSE,
      reverse = reverse))       
  }
  return(color_scale)
}

label_maker <- function(x, levels = NULL, labels = NULL, suffix = NULL) {
  # if (!is.null(labels)) {
  #   index <- sapply(x, \(.x) which(levels == .x)) # Using R's new lambda functions!
  #   x <- labels[index]
  # }
  if (is.numeric(x)) {
    x <- signif(x, 6)
  }
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

breaks_midpoints <- \(breaks, rescaler = scales::rescale, ...) {
  scaled_breaks <- rescaler(breaks, ...)
  midpoints <- head(scaled_breaks, -1) + diff(scaled_breaks)/2
  midpoints[length(midpoints)] <- midpoints[length(midpoints)] + .Machine$double.eps
  return(midpoints)
}

# Text Functions ----
read_md <- function(file) {
  md <- readLines(file)
  instruction_lines <- 1:grep("CITY CONTENT BEGINS HERE", md)
  mddf <- tibble(text = md[-instruction_lines]) %>%
    mutate(
      section = case_when(str_detect(text, "^//// ") ~ str_extract(text, "^/+ (.*)$", group = T), T ~ NA_character_),
      slide = case_when(str_detect(text, "^// ") ~ str_extract(text, "^/+ (.*)$", group = T), T ~ NA_character_),
      .before = 1) %>%
    tidyr::fill(section) %>% 
    { lapply(na.omit(unique(.$section)), \(sect, df) {
        df <- filter(df, section == sect) %>%
          tidyr::fill(slide, .direction = "down") %>%
          filter(!(slide != lead(slide) & text == "")) %>%
          filter(!str_detect(text, "^/") & !str_detect(text, "^----"))
        while (df$text[1] == "" & nrow(df) > 1) df <- df[-1,]
        while (tail(df$text, 1) == "" & nrow(df) > 1) df <- head(df, -1)
        return(df)
    }, df = .) } %>%
    bind_rows() #%>%
    # Do I want to remove header lines? For now, no
    # filter(!str_detect(text, "^#"))
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

double_space <- function(x) {
  str_replace(x, "\\n", "\n\n")
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

aspect_buffer <- function(x, aspect_ratio, buffer_percent = 0) {
  bounds_proj <- st_transform(st_as_sfc(st_bbox(x)), crs = 
    "EPSG:3857")
  center_proj <- st_coordinates(st_centroid(bounds_proj))

  long_distance <-max(c(
    st_distance(
      st_point(st_bbox(bounds_proj)[c("xmin", "ymin")]),
      st_point(st_bbox(bounds_proj)[c("xmax", "ymin")]))[1],
    st_distance(
      st_point(st_bbox(bounds_proj)[c("xmin", "ymax")]),
      st_point(st_bbox(bounds_proj)[c("xmax", "ymax")]))[1]))
  lat_distance <- max(c(
    st_distance(
      st_point(st_bbox(bounds_proj)[c("xmin", "ymin")]),
      st_point(st_bbox(bounds_proj)[c("xmin", "ymax")]))[1],
    st_distance(
      st_point(st_bbox(bounds_proj)[c("xmax", "ymin")]),
      st_point(st_bbox(bounds_proj)[c("xmax", "ymax")]))[1]))

  if (long_distance/lat_distance < aspect_ratio) long_distance <- lat_distance * aspect_ratio
  if (long_distance/lat_distance > aspect_ratio) lat_distance <- long_distance/aspect_ratio

  new_bounds_proj <-
  c(center_proj[,"X"] + (c(xmin = -1, xmax = 1) * long_distance/2 * (1 + buffer_percent)),
  center_proj[,"Y"] + (c(ymin = -1, ymax = 1) * lat_distance/2 * (1 + buffer_percent)))

  new_bounds <- st_bbox(new_bounds_proj, crs = "EPSG:3857") %>%
    st_as_sfc() %>%
    st_transform(crs = st_crs(x))

  return(new_bounds)
}

# Alternatively could be two separate functions: pretty_interval() and pretty_quantile()
break_pretty2 <- function(data, n = 6, method = "quantile", FUN = signif, 
                          digits = NULL, threshold = 1/(n-1)/4) {
  divisions <- seq(from = 0, to = 1, length.out = n)

  if (method == "quantile") breaks <- unname(stats::quantile(data, divisions, na.rm = T))
  if (method == "interval") breaks <- divisions *
    (max(data, na.rm = T) - min(data, na.rm = T)) +
    min(data, na.rm = T)

  if (is.null(digits)) {
    digits <- if (all.equal(FUN, signif)) 1 else if (all.equal(FUN, round)) 0
  }

  distribution <- ecdf(data)
  # pretty_breaks <- 0
  discrepancies <- 100
  while (any(abs(discrepancies) > threshold) & digits < 6) {
    if (all.equal(FUN, signif) == TRUE) {
      pretty_breaks <- FUN(breaks, digits = digits)
      if(all(is.na(str_extract(tail(pretty_breaks, -1), "\\.[^0]*$")))) pretty_breaks[1] <- floor(pretty_breaks[1])
    }
    if (all.equal(FUN, round) == TRUE) {
      pretty_breaks <- c(
        floor(breaks[1] * 10^digits) / 10^digits,
        FUN(tail(head(breaks, -1), -1), digits = digits),
        ceiling(tail(breaks, 1) * 10^digits) / 10^digits)
    }
    if (method == "quantile") discrepancies <- distribution(pretty_breaks) - divisions
    # if (method == "interval) discrepancies <- distribution(pretty_breaks) - distribution(breaks)
    if (method == "interval") {
      discrepancies <- (pretty_breaks - breaks)/ifelse(breaks != 0, breaks, pretty_breaks)
      discrepancies[breaks == 0 & pretty_breaks == 0] <- 0
    }

    digits = digits + 1
  }

  return(pretty_breaks)
}

include_html_chart <- \(file) cat(str_replace_all(readLines(file), "\\s+", " "), sep="\n")
