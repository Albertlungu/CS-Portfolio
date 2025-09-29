import xarray as xr
import h5netcdf
import h5py
import numpy as np
import matplotlib.pyplot as plt
import glob

folder = "/Users/albertlungu/CS-Portfolio/4-NASA Space Hacks/Data Analysis/CH2O/CH2O Results/"
files = glob.glob(folder + "*.nc")

plt.figure(figsize=(12,6))
last_scatter = None

for f in files:
    geo = xr.open_dataset(f, group = 'geolocation')
    prod = xr.open_dataset(f, group = 'product')

    lat = geo['latitude'].values
    lon = geo['longitude'].values
    ch2o = prod['vertical_column'].values

    ch2o = np.ma.masked_where(ch2o < 0, ch2o)

    last_scatter = plt.scatter(lon, lat, c = ch2o, s = 1, cmap = 'inferno_r')

# with h5py.File(file, 'r') as f:
#     print(list(f.keys()))


plt.colorbar(label="CH2O Column Amount (molec/cm^2)")
plt.xlabel("Longitude")
plt.ylabel("Latitude")
plt.title("TEMPO Formaldehyde (CH2O) L2")
plt.show()
