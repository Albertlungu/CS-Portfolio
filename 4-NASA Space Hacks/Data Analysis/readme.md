# OMI-Aura Tropospheric NO₂ Visualization

This project **downloads daily Level-3 OMI NO₂ data** and creates a **global map** showing the **5-day mean of tropospheric NO₂** using Python.

---

## Requirements

- **Python 3.9+**  
- Python packages:
  - `earthaccess`
  - `h5py`
  - `numpy`
  - `matplotlib`
  - `cartopy`

> **Tip:** Install everything quickly with:  
> `pip install earthaccess h5py numpy matplotlib cartopy`

---

## 1. Download NO₂ Data (`cloud_analysis.py`)

1. Run the script **`cloud_analysis.py`**.  
2. The script will **log in to NASA Earthdata** interactively.  
3. It will **search for NO₂ granules** from **Feb 1, 2024 to Dec 31, 2024** and download them.  
4. Files are saved in a folder called **`NO2 Results`**.  

> **Note:** A valid **NASA Earthdata account** is required.

---

## 2. Inspect the File Structure

Before processing the data, it’s recommended to **check the structure of the `.he5` files**:

- Verify that the dataset  
  **`HDFEOS/GRIDS/ColumnAmountNO2/Data Fields/ColumnAmountNO2Trop`** exists.  
- Check for **latitude (`Latitude`)** and **longitude (`Longitude`)** datasets if you want exact coordinates.  
- You can print the file structure using `h5py` to see all groups and datasets.

> **Tip:** This ensures that the script will read the correct datasets and avoids errors.

---

## 3. Process Data & Create Plot (`data_representation.py`)

1. Run **`data_representation.py`**.  
2. The script will:
   - Load the `.he5` files.
   - Replace fill values with **NaN**.
   - Compute a **5-day mean** of tropospheric NO₂.  
   - Plot a **global map** using `matplotlib` and `cartopy`.

3. The plot shows:
   - **Tropospheric NO₂ levels** in **mol/cm²**.
   - **Coastlines and borders** for reference.  

> **Optional:** Adjust latitude and longitude ranges or include more days for a larger dataset.

---

## Notes

- Fill values are converted to **NaN** to avoid affecting the mean.  
- If latitude/longitude datasets are not used, the script assumes a **1×1° global grid**:
  - Latitude: **-89.5° to 89.5°**  
  - Longitude: **-179.5° to 179.5°**  
- You can modify the scripts to include more granules or different time ranges.

---

## References

- [NASA Earthdata: OMI/Aura OMNO2d](https://earthdata.nasa.gov/)  
- [Cartopy Documentation](https://scitools.org.uk/cartopy/docs/latest/)

---

**Enjoy visualizing global NO₂ levels!**