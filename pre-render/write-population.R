# Is city in Oxford Economics?
oxford_locations <- readr::read_csv(paths$oxford_locations_file, col_types = "c")
oxford_locations_in_country <- dplyr::filter(oxford_locations, Country == country)
in_oxford <- city %in% oxford_locations_in_country$Location
if (!in_oxford) {
  print(glue::glue("{city} is not in Oxford Economics. The included locations for {country} are ",
             "{paste_and(unique(oxford_locations_in_country$Location))}. ",
              "Is one of these an alternate name or spelling for {city}?"))
}

if (!exists("oxford_full")) oxford_full <-
  read_csv(paths$oxford_file,
          col_types = "cccccccccdddddddddddddddddddddddddddddddddddddddddcllldlcclcc")

# Find 2021 (or most recent) population
if (in_oxford) {
  city_pop <- oxford_full %>%
    filter(Location == city & Indicator == "Total population") %>%
    .$`2021` * 1000
} else {
  pop <- un_de_pop_growth(city, country)
  city_pop <- filter(pop, Location == city) %>% slice_max(Year) %>% .$Population
}

# Find benchmark cities
nearby_cities <- oxford_locations %>%
  subset(str_detect(tolower(Country), city_params$nearby_countries_string)) %>%
  subset(Location != Country & !str_detect(Location, "Total")) %>%
  .$Location
# Select benchmark cities
bm_cities <- oxford_full %>%
  select(Location, Country, Indicator, `2021`) %>%
  subset(Location %in% nearby_cities & Indicator == "Total population") %>%
  subset((between(`2021`, city_pop*.5/1000, city_pop*1.5/1000) | Country == country) & Location != city) %>%
  .$Location

# Add manual benchmark cities
bm_cities <- c(bm_cities, city_params$bm_cities_manual) %>% unique() %>% which_not(city)

# Create population file
# Look in Oxford
oxford <- oxford_full %>%
  filter(Location %in% c(city, bm_cities))
if (nrow(oxford) > 0) {
  pop_oxford <- oxford %>%
    filter(
    Indicator == "Total population") %>%
    mutate(Group = case_when(Location == city ~ Location, T ~ "Benchmark") %>%
            factor(levels = c(city, "Benchmark"))) %>%
    select(Group, Location, Country, Indicator, matches('\\d')) %>%
      pivot_longer(cols = matches('^\\d'), names_to = "Year", values_to = "Value") %>%
      pivot_wider(values_from = Value, names_from = Indicator) %>%
      mutate(
        Year = as.numeric(Year),
        Population = `Total population` * 1000,
        Source = "Oxford",
        Method = "Oxford",
        .keep = "unused") %>%
      arrange(Group) %>% 
      subset(Year <= 2021 & !is.na(Population))
  bm_areas <- read_csv(paths$oxford_areas_file, col_types = "ccd") %>%
    mutate(Location = str_to_title(Location)) %>%
    filter(Location %in% str_to_title(pop_longitude$Location)) %>%
    select(-Country)
  if (any(duplicated(bm_areas$Location))) stop("Multiple Oxford Economics cities have been matched with the same name")
  pop_oxford <- left_join(pop_oxford, bm_areas, by = "Location")
} else {
  pop_oxford <- data.frame(
    Group = factor(),
    Location = character(),
    Country = character(),
    Year = numeric(),
    Population = numeric(),
    Source = character(),
    Method = character())
}

# Pop from citypopulation.de
non_oxford_cities <- which_not(c(city, city_params$bm_cities_manual), oxford$Location) %>% .[!duplicated(.)]
if (length(non_oxford_cities) > 0) {
pop_non_oxford <- non_oxford_cities %>%
  lapply(function(x) {
    country_temp <- non_oxford_cities[(non_oxford_cities == x)][1] %>% names()
    if (length(country_temp) != 0) if (country_temp != "") country <- country_temp
    data <- get_de_pop_growth(x, country = country)
    return(data)
  }) %>%
  bind_rows() %>%
  mutate(Location = str_extract(tolatin(Location), c(city, bm_cities) %>% paste(collapse = "|")),
         Method = "get_de_pop_growth()",
    Group = case_when(Location == city ~ city, T ~ "Benchmark"))
if (nrow(pop_non_oxford) > 0) pop_longitude <- bind_rows(pop_oxford, pop_non_oxford)
}

# Read manual population data
# BN: Probably don't need to do this if we are writing and reading from CSV
#     User could simply edit the CSV. Think through.
pop_manual <- read_csv(file.path(user_input_dir, "manual-data-entry/pop.csv"), col_types = "ccddc") %>%
  mutate(Method = "Manual")

pop_longitude <- bind_rows(pop_longitude, pop_manual)
pop_longitude <- pop_longitude %>%
  mutate(Area_km = case_when(
    Area_km == 0 ~ NA_real_,
    T ~ Area_km)) %>%
  group_by(Year, Location) %>%
  fill(Area_km, Population, Country, .direction = "updown") %>%
  ungroup() %>%
  distinct(Location, Year, Population, .keep_all = T)
write_csv(pop_longitude, file.path(process_output_dir, "population.csv"))

