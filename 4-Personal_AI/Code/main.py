import csv
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import os

fp = "Data/ex.csv" # fp for file path
df = pd.read_excel(fp) # df for data file

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