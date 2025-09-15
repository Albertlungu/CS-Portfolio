import leafmap
import pandas as pd

leafmap.nasa_data_login()

url = "https://github.com/opengeos/NASA-Earth-Data/raw/main/nasa_earth_data.tsv"
df = pd.read_csv(url, sep="\t")
df

results, gdf = leafmap.nasa_data_search(
    short_name="GEDI_L4A_AGB_Density_V2_1_2056",
    cloud_hosted=True,
    bounding_box=(-73.9872, -33.7683, -34.7299, 5.2444),
    temporal=("2020-07-01", "2020-07-31"),
    count=-1,  # use -1 to return all datasets
    return_gdf=True,
)

gdf.explore()

leafmap.nasa_data_download(results[:5], out_dir="Data Analysis/NO2 Results")

from leafmap import leafmap

m = leafmap.Map()
m.add("nasa_earth_data")
m