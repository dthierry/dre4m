################################################################################
#                    Copyright 2022, UChicago LLC. Argonne                     #
#       This Source Code form is subject to the terms of the MIT license.      #
################################################################################
# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80 tw=80

# created @dthierry 2022
# description: load dataframes with the excelt results
#
# log:
# 1-30-23 added some comments
#
#
#80#############################################################################

import sys
import pandas as pd
from typing import Tuple
from generalD import *
__author__ = "David Thierry"



def loadExcelOveralls(shift: bool=False) -> Tuple[dict, float]:
    """read the aggregates of the _effective.xlsx file, which is generated from
    the results.
    """
    excelFileName = getFiles("*_effective.xlsx")
    if not excelFileName:
        raise Exception("not found")
    ef = pd.ExcelFile(excelFileName)
    #b = pd.DataFrame()  # this doesn't work :S
    l = {}
    for name in names:
        count = 0
        kind = kinds[name]
        if max(kind) == 0:
            continue
        for i in range(I):
            print(name, kind)
            r = range(kind[i])
            for k in r:
                suffix = "" if name in ["w", "uw"] else "_" + str(k)
                #: sheet names for w and uw are different
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
            l[name] = l[name].shift(fill_value=0) #: shift by one
    return l, dmax


