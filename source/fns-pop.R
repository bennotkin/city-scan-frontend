library(readr)
library(rvest)
library(tidyr)

# Population functions
# Defining the UN Data and citypopulation.de pop function because it is used as backup in Oxford and in Density
get_un_pop_growth <- function(city, country = country) {
  # UN Data
  if (!file.exists(paths$undata_file)) {
    warning(paste0("undata_file (", paths$undata_file, ") does not exist."))
    return(NULL)
  } else {
    pop_growth_undata <- read_csv(paths$undata_file,
                                  col_types = "cdccccccddc", n_max = 69490) %>%
      filter(`Country or Area` == country) %>%
      filter(Sex == "Both Sexes") %>%
      filter(str_detect(tolower(tolatin(City)), tolower(tolatin(city)))) %>%
      select(Location = City, Year, Population = Value) %>%
      mutate(Source = "UN Data") %>%
      arrange(Year)
    return(pop_growth_undata)
  }
}  

# citypopulation.de
get_de_pop_growth <- function(city, country = country) {
  url <- paste0("https://www.citypopulation.de/en/", str_replace_all(tolower(country), " ", ""), "/cities/")
  table_ids = c("citysection", "largecities", "adminareas")
  for (id in table_ids) {
    de <- read_html(url) %>%
      html_node("section#citysection") %>%
      html_node("table") %>%
      html_table()
      if (any(str_detect(tolatin(de$Name), tolatin(city)))) break
    }

  pop_growth_de <- de %>%
    select(Location = Name, contains("Population"), Area = starts_with("Area")) %>%
    filter(str_detect(tolatin(Location), tolatin(city))) %>%
    pivot_longer(cols = contains("Population"), values_to = "Population", names_to = "Year") %>%
    mutate(
      Location = Location,
      Country = country,
      Year = str_extract(Year, "\\d{4}") %>% as.numeric(),
      Population = str_replace_all(Population, ",", "") %>% as.numeric(),
      Source = "citypopulation.de",
      Area_km = as.numeric(Area)/100,
      .keep = "unused") %>%
    arrange(Year)
  
  if (nrow(pop_growth_de) == 0) warning(glue::glue("No population data detected for {city} in citypopulation.de table"))
  if (length(unique(pop_growth_de$Location)) > 1) warning(glue::glue("More than one '{city}' detected in citypopulation.de table"))
  
  return(pop_growth_de)
}

un_de_pop_growth <- function(city, country) {
  # Select whether to use citypopulation.de or UN data based on which has more data
  # Alternatively, can plot both, coloring each line by Source column
  pop_growth <- bind_rows(get_un_pop_growth(city, country),
                          get_de_pop_growth(city, country))
  return(pop_growth)
}

tolatin <- function(x) stringi::stri_trans_general(x, id = "Latin-ASCII")
