import pandas as pd

# -----------------------------
# Resource List
# -----------------------------
resources = [
    {
        "Title": "WHO Air Pollution",
        "Type": "Website",
        "Purpose": "Global air pollution info, health effects, mitigation",
        "Access": "Web"
    },
    {
        "Title": "60 Second Science: Air Quality",
        "Type": "Video",
        "Purpose": "Explain air quality basics and importance",
        "Access": "Web"
    },
    {
        "Title": "NASA Air Pollution Webinar Series",
        "Type": "Webinar",
        "Purpose": "How NASA measures and visualizes air pollution",
        "Access": "Web"
    },
    {
        "Title": "TEMPO Air Quality Observation Data",
        "Type": "Dataset",
        "Purpose": "Satellite NO2, HCHO, AI, PM, O3 data for research",
        "Access": "NASA Earthdata (Python/API/Download)"
    },
    {
        "Title": "SPoRt Viewer – Near Real-Time",
        "Type": "Tool/Visualization",
        "Purpose": "Near real-time satellite visualizations",
        "Access": "Web"
    },
    {
        "Title": "ASDC Resource Hub",
        "Type": "Website/Tutorials",
        "Purpose": "Guidance and tutorials for NASA mission data",
        "Access": "Web / RSIG-py"
    },
    {
        "Title": "TRMM Multi-satellite Precipitation Analysis (TMPA)",
        "Type": "Dataset",
        "Purpose": "Rainfall estimates at 3-hour/1-day intervals",
        "Access": "NASA Earthdata / Download / API"
    },
    {
        "Title": "IMERG Precipitation Data",
        "Type": "Dataset",
        "Purpose": "Integrated satellite rainfall data, multiple latencies",
        "Access": "NASA Earthdata / API"
    },
    {
        "Title": "Daymet Weather Data",
        "Type": "Dataset/Model",
        "Purpose": "Daily weather and climatology variables",
        "Access": "NASA Earthdata / API"
    },
    {
        "Title": "NASA Worldview",
        "Type": "Tool/Visualization",
        "Purpose": "Browse satellite imagery interactively",
        "Access": "Web"
    },
    {
        "Title": "AIRS Relative Humidity & Temperature",
        "Type": "Dataset/Observation",
        "Purpose": "Daily surface/atmosphere measurements",
        "Access": "NASA Earthdata / Download / API"
    },
    {
        "Title": "MERRA-2 Reanalysis Data",
        "Type": "Dataset/Reanalysis",
        "Purpose": "Historical temperature, humidity, wind, PBL height",
        "Access": "NASA Earthdata / API"
    },
    {
        "Title": "NOAA CYGNSS Wind Data",
        "Type": "Dataset/Observation",
        "Purpose": "Satellite-derived wind speed/direction",
        "Access": "NOAA / API / Download"
    },
    {
        "Title": "NASA Pandora Project",
        "Type": "Ground Station Network",
        "Purpose": "UV/visible spectroscopy for atmospheric composition",
        "Access": "Web / Download"
    },
    {
        "Title": "NASA TOLNet",
        "Type": "Ground Station Network",
        "Purpose": "Tropospheric ozone high-res observations",
        "Access": "Web / Download"
    },
    {
        "Title": "AirNow",
        "Type": "Ground Station Network",
        "Purpose": "US air quality measurements",
        "Access": "Web / Download"
    },
    {
        "Title": "OpenAQ",
        "Type": "Ground Station Network / API",
        "Purpose": "Historic and real-time air quality data",
        "Access": "API / Web"
    },
    {
        "Title": "Earthdata Login (EDL)",
        "Type": "Portal / Account",
        "Purpose": "Single login to access NASA Earthdata",
        "Access": "Web"
    },
    {
        "Title": "NASA WorldView & Giovanni",
        "Type": "Web Tools",
        "Purpose": "Browse, visualize, analyze geophysical parameters",
        "Access": "Web"
    },
    {
        "Title": "Earthdata Search & Earthaccess",
        "Type": "API / Python Library",
        "Purpose": "Programmatic search and download of NASA Earth science data",
        "Access": "Python library / Web / Cloud"
    },
    {
        "Title": "Xarray & Cloud Cookbook",
        "Type": "Python Library / Tutorials",
        "Purpose": "Process large NASA datasets in local/cloud environments",
        "Access": "Python / Cloud"
    },
    {
        "Title": "OPeNDAP & Harmony",
        "Type": "API / Programmatic Tool",
        "Purpose": "Access and transform NASA Earth observation data",
        "Access": "Python / API / Web"
    },
    {
        "Title": "GIBS API & AppEEARS",
        "Type": "API / Tool",
        "Purpose": "Access global imagery & analysis-ready samples",
        "Access": "Python / API / Cloud"
    }
]

# -----------------------------
# Create DataFrame
# -----------------------------
df = pd.DataFrame(resources)

# -----------------------------
# Display table
# -----------------------------
pd.set_option("display.max_rows", None)  # Show all rows
pd.set_option("display.max_colwidth", 100)  # Prevent truncating text

print(df)

# Optional: save to CSV
df.to_csv("air_quality_resources_summary.csv", index=False)