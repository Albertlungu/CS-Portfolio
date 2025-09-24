import h5py
import numpy as np
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature

# Your files
files = [
    "/Users/albertlungu/CS-Portfolio/4-NASA Space Hacks/Data Analysis/NO2/NO2 Results/OMI-Aura_L3-OMNO2d_2024m0201_v003-2024m0307t130621.he5",
    "/Users/albertlungu/CS-Portfolio/4-NASA Space Hacks/Data Analysis/NO2/NO2 Results/OMI-Aura_L3-OMNO2d_2024m0202_v003-2024m0307t130726.he5",
    "/Users/albertlungu/CS-Portfolio/4-NASA Space Hacks/Data Analysis/NO2/NO2 Results/OMI-Aura_L3-OMNO2d_2024m0203_v003-2024m0306t205503.he5",
    "/Users/albertlungu/CS-Portfolio/4-NASA Space Hacks/Data Analysis/NO2/NO2 Results/OMI-Aura_L3-OMNO2d_2024m0204_v003-2024m0306t205541.he5",
    "/Users/albertlungu/CS-Portfolio/4-NASA Space Hacks/Data Analysis/NO2/NO2 Results/OMI-Aura_L3-OMNO2d_2024m0205_v003-2024m0307t130709.he5"
]

data_list = []

for f in files:
    with h5py.File(f, 'r') as hdf:
        # Dataset path in Level-3 OMI files
        dset = hdf['HDFEOS/GRIDS/ColumnAmountNO2/Data Fields/ColumnAmountNO2Trop'][:]
        # Replace fill values with NaN
        dset = np.where(dset < 0, np.nan, dset)
        data_list.append(dset)

# Stack and average
stacked = np.stack(data_list, axis=0)
mean_data = np.nanmean(stacked, axis=0)

# Latitude and longitude from L3 (OMNO2d is 1x1 degree global grid)
lat = np.arange(-89.5, 90.5, 1.0)   # 180 values
lon = np.arange(-179.5, 180.5, 1.0) # 360 values
lon_grid, lat_grid = np.meshgrid(lon, lat)

# Plot
fig = plt.figure(figsize=(14, 7))
ax = plt.axes(projection=ccrs.PlateCarree())
c = ax.pcolormesh(lon_grid, lat_grid, mean_data,
                  transform=ccrs.PlateCarree(),
                  cmap='inferno',
                  shading='auto')

ax.add_feature(cfeature.BORDERS, linewidth=0.5)
ax.add_feature(cfeature.COASTLINE, linewidth=0.5)
ax.set_title("OMI-Aura (L3) Tropospheric NO₂ (5-day Mean)", fontsize=14)

cbar = plt.colorbar(c, orientation='vertical', shrink=0.7, pad=0.05)
cbar.set_label("NO₂ Tropospheric Column (mol/cm²)")

plt.show()

# def print_structure(name, obj):
#     print(name)
# for idx, i in enumerate(files):
#     with h5py.File(i, 'r') as f:
#         print("FILE", idx+1)
#         f.visititems(print_structure)
#         print("\n")