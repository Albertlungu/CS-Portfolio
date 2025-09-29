"""
Air Quality Forecast MVP — TEMPO + ground + weather (prototype)
Albert Lungu
NASA Space Apps Challenge

This prototype integrates OpenAQ (ground), weather data, and TEMPO (stubbed)
to visualize local air quality and forecasts.

"""

import requests
import pandas as pd
import streamlit as st
from datetime import datetime, timedelta

# -------------------------
# CONFIG
# -------------------------
CITY_NAME = "Ottawa"
CITY_COORDS = (45.4215, -75.6972)  # Ottawa fallback coordinates
RADIUS = 10000  # meters

# -------------------------
# HELPERS
# -------------------------
def fetch_openaq_latest(lat, lon, radius=10000):
    url = f"https://api.openaq.org/v2/latest?coordinates={lat},{lon}&radius={radius}&limit=100"
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        data = r.json()
        if "results" not in data or not data["results"]:
            return pd.DataFrame()
        rows = []
        for item in data["results"]:
            loc = item.get("location")
            for m in item.get("measurements", []):
                rows.append({
                    "location": loc,
                    "parameter": m.get("parameter"),
                    "value": m.get("value"),
                    "unit": m.get("unit"),
                    "date": m.get("lastUpdated"),
                    "lat": item.get("coordinates", {}).get("latitude"),
                    "lon": item.get("coordinates", {}).get("longitude"),
                })
        return pd.DataFrame(rows)
    except Exception as e:
        st.error(f"OpenAQ latest fetch failed: {e}")
        return pd.DataFrame()


def fetch_openaq_history(lat, lon, parameter="no2", days=7, radius=10000):
    date_to = datetime.utcnow()
    date_from = date_to - timedelta(days=days)
    url = (
        f"https://api.openaq.org/v2/measurements?"
        f"coordinates={lat},{lon}&radius={radius}"
        f"&parameter={parameter}"
        f"&date_from={date_from.isoformat()}Z"
        f"&date_to={date_to.isoformat()}Z"
        "&limit=10000&sort=desc"
    )
    try:
        r = requests.get(url, timeout=15)
        r.raise_for_status()
        data = r.json()
        if "results" not in data or not data["results"]:
            return pd.DataFrame()
        rows = []
        for m in data["results"]:
            rows.append({
                "parameter": m.get("parameter"),
                "value": m.get("value"),
                "unit": m.get("unit"),
                "date": m.get("date", {}).get("utc"),
                "lat": m.get("coordinates", {}).get("latitude"),
                "lon": m.get("coordinates", {}).get("longitude"),
            })
        return pd.DataFrame(rows)
    except Exception as e:
        st.error(f"OpenAQ history fetch failed: {e}")
        return pd.DataFrame()


def fetch_weather(lat, lon):
    # Simple weather example via Open-Meteo
    url = (
        f"https://api.open-meteo.com/v1/forecast?"
        f"latitude={lat}&longitude={lon}"
        "&hourly=temperature_2m,relative_humidity_2m,windspeed_10m"
    )
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        data = r.json()
        return data
    except Exception as e:
        st.error(f"Weather fetch failed: {e}")
        return {}


# -------------------------
# STREAMLIT DASHBOARD
# -------------------------
st.title("🌍 Air Quality Forecast MVP")
st.subheader("TEMPO + Ground + Weather Prototype")

st.write(f"Fetching OpenAQ latest for **{CITY_NAME}**...")

latest = fetch_openaq_latest(*CITY_COORDS, radius=RADIUS)
if latest.empty:
    st.warning("⚠️ No latest records from OpenAQ — showing fallback coords.")
else:
    st.success("✅ Got latest ground data from OpenAQ.")
    st.dataframe(latest.head())

# Historical NO2
st.write("### Historical & forecast for NO₂")
history = fetch_openaq_history(*CITY_COORDS, parameter="no2", days=7, radius=RADIUS)
if history.empty:
    st.warning("⚠️ No historical NO₂ data from OpenAQ.")
else:
    st.line_chart(history.set_index("date")["value"])

# Weather
st.write("### Weather near Ottawa")
weather = fetch_weather(*CITY_COORDS)
if "hourly" in weather:
    df_weather = pd.DataFrame(weather["hourly"])
    st.line_chart(df_weather.set_index("time")[["temperature_2m", "windspeed_10m"]])
else:
    st.warning("⚠️ No weather data fetched.")

# TEMPO placeholder
st.write("### 🚀 TEMPO Data (coming soon)")
st.info("TEMPO satellite integration can be added here.")