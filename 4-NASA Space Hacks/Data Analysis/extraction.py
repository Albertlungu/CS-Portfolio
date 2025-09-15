import netCDF4 as nc
import h5py
import numpy as np

filename = "Data Analysis/NO2 Results/TEMPO_NO2_L3_V03_20240201T130215Z_S002.nc"
with h5py.File(filename, 'r') as f:
    print("Top-level groups")
    print(list(f.keys()))

with h5py.File(filename, "r") as f:
    def print_structure(name, obj):
        if isinstance(obj, h5py.Dataset):
            print(f"Dataset: {name}, shape: {obj.shape}, dtype: {obj.dtype}")
    f.visititems(print_structure)

