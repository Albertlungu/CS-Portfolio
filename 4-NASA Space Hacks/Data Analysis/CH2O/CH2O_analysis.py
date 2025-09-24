import earthaccess
from pathlib import Path

auth = earthaccess.login()
print(auth.authenticated)

# try:
#     datasets_formaldehyde = earthaccess.search_datasets(
#         keyword = "Formaldehyde",
#         cloud_hosted = True,
#         count = 5
#     )
#     datasets_ch2o = earthaccess.search_datasets(
#         keyword = "CH2O",
#         cloud_hosted = True,
#         count = 5
#     )
# except RuntimeError as e:
#     print("Server error, try again later: ", e)

# print(*datasets_formaldehyde, *datasets_ch2o)

ch2o_results = earthaccess.search_data(
    short_name = "TEMPO_HCHO_L2",
    count = 5
)

files = earthaccess.download(granules=ch2o_results, local_path="/Users/albertlungu/CS-Portfolio/4-NASA Space Hacks/Data Analysis/CH2O/CH2O Results")
print(files)