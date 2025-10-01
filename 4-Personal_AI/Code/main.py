import csv
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import openpyxl

import os

fp_book1 = "/Users/albertlungu/Documents/GitHub/CS-Portfolio/4-Personal_AI/Data/analytics_book.xlsx" # fp for file path
fp_raw_data = "/Users/albertlungu/Documents/GitHub/CS-Portfolio/4-Personal_AI/Data/raw_data.xlsx"
df = pd.read_excel(fp_raw_data, sheet_name=0, dtype=str) # df for data file


def main():
    # plot_data(read_csv(fp)[0])
    # sns.regplot(
    #     data = df, 
    #     x = 'Units_Sold', 
    #     y = 'Revenue', 
    #     order = 3,
    #     ci = None)
    # plt.show()
    print(df)

if __name__ == "__main__":
    main()