import sys
import pandas as pd
from typing import Tuple
from generalD import *
__author__ = "David Thierry"

def loadExcelDfs(shift: bool=False):
    excelFileName = "/Users/dthierry/Projects/plantsAnl/my_new_file.xlsx"
    I = 10 # Ten kinds of pp
    #names = ["w", "z", "x"]
    ef = pd.ExcelFile(excelFileName)
 

def loadExcelOveralls(shift: bool =False) -> Tuple[dict, float]:
    excelFileName = getFiles("*_effective.xlsx")
    if not excelFileName:
        raise Exception("not found")
    ef = pd.ExcelFile(excelFileName)
    #b = pd.DataFrame()  # this doesn't work :S
    l = {}
    for name in names: 
        count = 0
        for i in range(I):
            kind = kinds[name]
            r = range(kind[i])
            for k in r:
                suffix = "" if name in ["w", "uw"] else "_" + str(k)
                sheetName = name + "_" + str(i) + suffix
                print(sheetName)
                df = ef.parse(sheet_name=sheetName, index_col=0)
                df = df.drop(columns="Unnamed: 1") # might delete later
                series = df.sum(axis=1) # sum over age
                series.name = sheetName 
                if count == 0:
                    b = pd.DataFrame(series)
                else:
                    d = pd.DataFrame(series)
                    b = b.join(d)
                count += 1
        l[name] = b

    d = ef.parse(sheet_name="d", index_col=0)
    d.drop(d.tail(1).index, inplace=True)
    l["demand"] = d
    dmax = d.max()[0]
    if shift:
        for name in names:
            if name == "w":
                continue
            l[name] = l[name].shift(fill_value=0) # shift by one
    return l, dmax


