#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pandas as pd
import os


filecc0="/Users/dthierry/Projects/raids/instance/ins2_1v4/c5e-01"
filebau0="/Users/dthierry/Projects/raids/instance/ins2_1v4/b5-01"

def get_folders(directory):
    print(directory)
    fulladdress = []
    d = []
    dirs = os.listdir(directory)
    print(dirs)
    for i in dirs:
        k = os.path.join(directory, i)
        if os.path.isdir(k):
            fulladdress.append(k)
            d.append(i)
            print(k)
    actDict = {}
    idx = 0
    for i in d:
        s = i.split("_")[4:]
        key = ""
        for j in s:
            key += j + "_"
        key = key[:-1]
        actDict[key] = fulladdress[idx]
        idx += 1
    suffix = "_stats.xlsx"
    for k in actDict.keys():
        fn = actDict[k].split("/")[-1] + suffix
        actDict[k] = os.path.join(actDict[k], fn)
        print(k, fn)
    return actDict


def get_files(file):
    suffix = "_stats.xlsx"
    with open(file, "r") as f:
        lines = f.readlines()
    fileDict = {}
    for l in lines:
        #: split
        s = l.split()
        fn = s[0].split("/")[-1] + suffix
        fileDict[s[1]] = s[0] + "/" + fn
    return fileDict

def coalesce():
    filescco = get_folders(filecc0)
    filesbau = get_folders(filebau0)
    print(filescco)
    print(filesbau)
    lef0 = [filescco["NoRF_NoCLT"], # ef_nrf_nclt
            filescco["NoRF_CLT"], # ef_nrf_clt,
            filescco["RF_NoCLT"], # ef_rf_nclt,
            filescco["RF_CLT"], # ef_rf_clt,
            filesbau["BAU_NoRF_NoCLT"],  #ef_nrf_nclt_bau,
            filesbau["BAU_NoRF_CLT"], #ef_nrf_clt_bau,
            filesbau["BAU_RF_NoCLT"], #ef_rf_nclt_bau,
            filesbau["BAU_RF_CLT"], #ef_rf_clt_bau
            ]


    titles = ["nrf_nclt", "nrf_clt", "rf_nclt", "rf_clt",
              "bau_nrf_nclt", "bau_nrf_clt", "bau_rf_nclt", "bau_rf_clt"]

    has_retro = [False, False, True, True,
                 False, False, True, True]


    has_clt = [False, True, False, True,
                 False, True, False, True]


    is_bau = [False, False, False, False,
              True, True, True, True]

    # we need to know the spreadsheet names first
    pdef = pd.ExcelFile(lef0[0])
    sheet_names = pdef.sheet_names
    with pd.ExcelWriter("coalesce.xlsx", mode="w") as writer:
        df = pd.DataFrame(["next sheet"])
        df.to_excel(writer, sheet_name="next")

    for sh_n in sheet_names:
        #if sh_n != "ccost_retro":
        #    continue
        #d0 = pd.DataFrame()
        k = 0
        lef = lef0.copy()
        rftagl = has_retro.copy()
        clttagl = has_clt.copy()
        bautagl = is_bau.copy()
        titlesl = titles.copy()
        while len(lef) != 0:
            ef = lef.pop()
            pdef = pd.ExcelFile(ef)
            head = titlesl.pop()
            # read the dataframe
            df1 = pdef.parse(sheet_name=sh_n, header=None)
            #: justfornow
            if len(df1.columns) == 2:
                df1.columns = [0, head]
            # attach the tags
            dft = pd.DataFrame([["has_retro", rftagl.pop()],
                                ["has_clt", clttagl.pop()],
                                ["is_bau", bautagl.pop()]],
                               columns=[0, head])
            df1 = pd.concat([df1, dft])
            if k != 0:
                df0 = pd.merge(df0, df1, on=0, how="outer")
            else:
                df0 = df1
            k += 1
        with pd.ExcelWriter("coalesce.xlsx", mode="a") as writer:
            df0.to_excel(writer, sheet_name=f"{sh_n}")
        #df0.to_csv(f"{sh_n}.csv")




if __name__ == "__main__":
    coalesce()
