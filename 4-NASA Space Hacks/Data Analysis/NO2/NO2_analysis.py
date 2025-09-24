import earthaccess
from pathlib import Path

# Login interactively
auth = earthaccess.login(strategy="interactive")
print("Authenticated:", auth.authenticated)

# Search for NO2 dataset (OMNO2d daily gridded NO2)
no2_results = earthaccess.search_data(
    short_name="OMNO2d",
    temporal=("2024-02-01", "2024-12-31"),
    count=5
)

print("Found granules:", len(no2_results))

# Make sure output directory exists
output_dir = Path("NO2 Results")
output_dir.mkdir(parents=True, exist_ok=True)

# Download results
files = earthaccess.download(no2_results, local_path=output_dir)
print("Downloaded files:", files)