# Required libraries
import requests
from bs4 import BeautifulSoup
import pandas as pd
# import re

def get_de_pop_growth(city, country):
  url = f'https://www.citypopulation.de/en/{country.lower().replace(" ", "")}/cities/'
  # Scrape data from the citypopulation.de
  response = requests.get(url)
  soup = BeautifulSoup(response.content, 'html.parser')
  html_table = soup.find('section', id = 'citysection').find('table')
  def get_pop(city, soup, table_id):
      html_table = soup.find('section', id = table_id).find('table')
      cities_df = pd.read_html(str(html_table))[0]
      city_pop = cities_df[cities_df['Name'].str.contains(city)]
      return(city_pop)
  # Look through tables on page for city name
  table_ids = ['citysection', 'largecities', 'adminareas']
  for id in table_ids:
    print(id)
    city_pop = get_pop(city, soup, id)
    if len(city_pop) > 0:
        break
  # Pivot longer: one column for years, one column for population
  cols = city_pop.columns
  pop_cols = cols[cols.str.contains('Population')]
  pop_df = pd.melt(city_pop, id_vars = ['Name', 'Area'], value_vars = pop_cols, var_name = 'Year', value_name='Population')
  # Rename and reformat columns
  pop_df['Year'] = pop_df['Year'].str.extract(r'(\d{4})').astype(int)
  pop_df['Population'] = pop_df['Population'].astype(int)
  pop_df['Source'] = 'citypopulation.de'
  pop_df['Area_km'] = pop_df['Area'].astype(int)/100
  pop_df = pop_df.rename(columns = {'Name': 'Location'})
  pop_df = pop_df[['Location', 'Year', 'Population', 'Area_km', 'Source']]
  # Sort by year
  pop_df = pop_df.sort_values(by = 'Year')
  return(pop_df)

pop_df = get_de_pop_growth(city, country)
pop_df.to_csv('')