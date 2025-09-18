import earthaccess
from pathlib import Path

auth = earthaccess.login()

try:
    datasets = earthaccess.search_datasets(
        keyword='NO2',
        cloud_hosted=True,
        temporal=("2023-01-01", "2023-12-31"),
        count=5
    )
except RuntimeError as e:
    print("Server error, try again later:", e)
for _ in datasets:
    print(_)


# no2_results = earthaccess.search_data(
#     short_name = "TEMPO_NO2_L3",
#     temporal = ("2024-02", "2024-12"),
#     cloud_hosted = True,
#     count = 5
# )


# files = earthaccess.download(no2_results, local_path='Data Analysis/NO2 Results')


# output_dir = Path("Data Analysis/Results")
# output_dir.mkdir(parents=True, exist_ok=True)

# for granule in no2_results:
#     try:
#         granule.download(local_path=output_dir)
#         print(f"Downloaded granule: {granule.granule_ur}")
#     except Exception as e:
#         print(f"Failed to download granule {granule.granule_ur}: {e}")
