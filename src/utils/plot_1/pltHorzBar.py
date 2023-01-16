#!/usr/bin/env python
#vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80 tw=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os, fnmatch

plt.rcParams.update({
    "text.usetex": True,
    "font.family": "serif",
    "font.serif": ["Palatino"],
})


# file = "/Users/dthierry/Projects/raids/src/utils/coalesce/v1/coalesce.xlsx"

# eFile = pd.ExcelFile(file)

def whichRetrofit(series) -> bool:
    resRfList = []
    resClList = []
    resBaList = []
    for i in series.index:
        rRf = False
        rCl = False
        rBa = False
        l = i.split("_")
        while len(l) != 0:
            label_ = l.pop()
            if label_ == "RF":
                rRf = True
            elif label_ == "CLT":
                rCl = True
            elif label_ == "BAU":
                rBa = True
        resRfList.append(rRf)
        resClList.append(rCl)
        resBaList.append(rBa)
    return resRfList, resClList, resBaList

def getFiles(pattern, path="."):
    result = []
    for root, dirs, files in os.walk(path):
        for name in files:
            if fnmatch.fnmatch(name, pattern):
                result.append(os.path.join(root, name))
                print("Using file {}".format(os.path.join(root, name)))
                return os.path.join(root, name)
    return None



# old_capacity_ret, old_RetCost
# retro_alloc
# retro_retired

# new_alloc, cap_cost_new
# (no new retired)
def plot_cap_bars():
    clrl = ["#00AA8E",
            "#0071AA",
            "#001CAA",
            "#3900AA",
            "#AA001C",
            "#AA8E00"]
    file = getFiles("coalesce.xlsx", path=".")
    print(file)
    eFile = pd.ExcelFile(file)

    df1 = eFile.parse(sheet_name="old_capacity_ret", index_col=0)
    old_cap_ret = -1*df1.tail(1).iloc[0, 1:]

    df2 = eFile.parse(sheet_name="retro_alloc", index_col=0)
    #retro_alloc = df2.iloc[12, 1:]
    retro_alloc = df2.tail(1).iloc[0, 1:]

    df3 = eFile.parse(sheet_name="retro_retired", index_col=0)
    #retro_retired = -1*df3.iloc[12, 1:]
    retro_retired = -1*df3.tail(1).iloc[0, 1:]

    df4 = eFile.parse(sheet_name="cap_cost_retro", index_col=0)
    #cc_retro = df4.iloc[12, 1:]
    cc_retro = df4.tail(1).iloc[0, 1:]

    df5 = eFile.parse(sheet_name="retro_RetCost", index_col=0)
    #rc_retro = df5.iloc[12, 1:]
    rc_retro = df5.tail(1).iloc[0, 1:]

    oc_retro = cc_retro + rc_retro

    y_pos = np.arange(len(old_cap_ret))

    f, a = plt.subplots(dpi=100)

    a.barh(y_pos, retro_retired, align="center", color="gold",
           label="retirements retro")
    a.barh(y_pos, retro_alloc, align="center", color="deepskyblue",
           label="retrofits")

    a.set_yticks(y_pos, labels=old_cap_ret.index)
    a.set_xlabel("GW")
    a.legend(loc=0)
    a1 = a.twiny()
    a1.barh(y_pos, cc_retro, align="center", height=0.5, left=0, color="navy",
            label="retro Cap cost", linewidth=1, edgecolor="k")
    a1.barh(y_pos, rc_retro, align="center", height=0.5, left=cc_retro,
            color="gold", label="retro ret Cost", linewidth=1, edgecolor="k")
    a1.set_xlabel("Millions \$")
    a1.ticklabel_format(axis="x", style='sci', scilimits=(-3, 3))
    a1.legend(loc=2)

    axlim = a.get_xlim()
    print(f"xlims {axlim[0]}, {axlim[1]}")
    ax_ratio = axlim[0]/axlim[1]
    print(f"ratio of x-axis {ax_ratio}")
    a1.set_xlim(left=a1.get_xlim()[1]*ax_ratio)

    f.savefig("retrofit.png", bbox_inches="tight")
    f.clf()

    df6 = eFile.parse(sheet_name="old_RetCost", index_col=0)
    #rc_old = df6.iloc[12, 1:]
    rc_old = df6.tail(1).iloc[0, 1:]

    df7 = eFile.parse(sheet_name="new_alloc", index_col=0)
    #new_alloc = df7.iloc[15, 1:]
    new_alloc = df7.tail(1).iloc[0, 1:]

    df8 = eFile.parse(sheet_name="cap_cost_new", index_col=0)
    #cc_new = df8.iloc[15, 1:]
    cc_new = df8.tail(1).iloc[0, 1:]

    df9 = eFile.parse(sheet_name="new_RetCost", index_col=0)
    #rc_new = df9.iloc[15, 1:]
    rc_new = df9.tail(1).iloc[0, 1:]

    f, a = plt.subplots(dpi=100)

    a.barh(y_pos, old_cap_ret, align="center",
           color=clrl[0], label="retirements old")

    a.barh(y_pos, new_alloc, align="center",
           color=clrl[1], label="new")

    a.set_yticks(y_pos, labels=old_cap_ret.index)
    a.set_xlabel("GW")
    a1 = a.twiny()
    a1.barh(y_pos, cc_new, align="center", height=0.5, left=0,
            color=clrl[2],
            label="new Cap.C", linewidth=0.1, edgecolor="k")
    a1.barh(y_pos, rc_old, align="center", height=0.5, left=cc_new,
            color=clrl[3],
            label="old ret Cost", linewidth=0.1, edgecolor="k")
    a1.barh(y_pos, rc_new, align="center", height=0.5, left=cc_new+rc_old,
            color=clrl[4],
            label="new ret Cost", linewidth=0.1, edgecolor="k")
    a1.set_xlabel("Millions \$")
    #a1.ticklabel_format(axis="x", style='sci', scilimits=(3, 4))
    #
    a.legend(loc=0)
    a1.legend(loc=2)

    axlim = a.get_xlim()
    print(f"xlims {axlim[0]}, {axlim[1]}")
    ax_ratio = axlim[0]/axlim[1]
    print(f"ratio of x-axis {ax_ratio}")
    a1.set_xlim(left=a1.get_xlim()[1]*ax_ratio)
    f.savefig("oldNnew.png", bbox_inches="tight")

def plot_em_bars():
    file = getFiles("coalesce.xlsx", path=".")
    print(file)
    eFile = pd.ExcelFile(file)
    df1 = eFile.parse(sheet_name="old_co2", index_col=0)
    df2 = eFile.parse(sheet_name="retro_co2", index_col=0)
    df3 = eFile.parse(sheet_name="new_co2", index_col=0)
    o_co2 = df1.iloc[6, 1:]
    r_co2 = df2.iloc[12, 1:]
    n_co2 = df3.iloc[9, 1:]
    x_pos = np.arange(len(o_co2))
    f, a = plt.subplots(dpi=200)
    b1 = a.bar(x_pos, o_co2, align="center",
               color="#AD1272",
               label="Exists. CO2",
               alpha=0.8)
    b2 = a.bar(x_pos, r_co2, bottom=o_co2,
               align="center",
               color="#136D9C",
               label="Retro. CO2")
    b3 = a.bar(x_pos, n_co2, bottom=o_co2+r_co2,
               align="center",
               color="#80BF10",
               label="New CO2")
    #
    tot = o_co2.add(r_co2)
    tot = tot.add(n_co2)
    #
    b = a.bar(x_pos, tot, align="center", color="none")
    #
    whichRf, whichCl, whichBa = whichRetrofit(tot)

    for i in range(len(b)):
        if whichRf[i]:
            b[i].set_lw(1)
            color = "r" if whichCl[i] else "k"
            b[i].set_edgecolor(color)
        if whichBa[i]:
            b[i].set_hatch("/")

    ticks = a.set_xticks(x_pos, labels=tot.index, rotation=90)
    for i in range(len(ticks)):
        if whichRf[i]:
            color = "r" if whichCl[i] else "k"
            ticks[i].get_children()[3].set_color(color)
            # print(ticks[i].get_children())

    a.set_title("Overall CO_2")
    a.bar_label(b, padding=-50, fmt="%.2E", rotation=90)
    a.set_ylabel("Million tCO2")
    a.ticklabel_format(style="sci", axis="y", scilimits=(-1, 4))
    legend = a.legend(loc="lower left",
        bbox_to_anchor=(1.0, 0.0))
    f.savefig("co2.png", bbox_inches="tight")

def plot_npv_bars():
    clrl = ["tomato", #"#15D666",
            "#15D6C7",
            "#1585D6",
            "#1524D6",
            "#D61585",
            "#C615D6",
            "#D61525",
            "#6615D6",
            "#D66615",
            "#00D659",
            "#00D6C4",
            "#007DD6",
            "#0012D6",
            "#D6007D",
            "#C400D6",
            "#D60012",
            "#5900D6",
            "#D65900"]
    cost_sheets = ["cap_cost_retro", "cap_cost_new",
                   "old_VoNm", "retro_VoNm", "new_VoNm",
                   "old_FoNm", "retro_FoNm", "new_FoNm",
                   "old_RetCost", "retro_RetCost", "new_RetCost",
                   "old_fuel", "retro_fuel", "new_fuel"]
    labels = [
        "Cap. cost retro.",
        "Cap. cost new",
        "Exist. V O\&M c.",
        "Retro. V O\&M c.",
        "New V O\&M c.",
        "Exist. F O\&M c.",
        "Retro. F O\&M c.",
        "New F O\&M c.",
        "Exist. Retire. c.",
        "Retro. Retire. c.",
        "New Retire. c.",
        "Exist. Fuel c.",
        "Retro. Fuel c.",
        "New Fuel c."]

    row = [12, 15,
           12, 12, 15,
           12, 12, 15,
           12, 12, 15,
           7, 12, 10]
    file = getFiles("coalesce.xlsx", path=".")
    eFile = pd.ExcelFile(file)
    i = 0
    x_pos = np.arange(2)
    f, a = plt.subplots(dpi=200)
    #a.grid(visible=True, which="major", axis="y")
    for cs in cost_sheets:
        df = eFile.parse(sheet_name=cs, index_col=0)
        s = df.iloc[row[i], 1:]
        if i == 0:
            s0 = pd.Series(np.zeros(s.size))
        print(i, cs, row[i], s, s0)
        x_pos = np.arange(len(s))
        b = a.bar(x_pos,
                  s,
                  align="center",
                  bottom=s0,
                  label=labels[i],
                  color=clrl[i])
        if i == 0:
            s0 = s.copy()
        else:
            s0 = s0.add(s)
        i += 1
    whichRf, whichCl, whichBa = whichRetrofit(s)
    b = a.bar(x_pos, s0, align="center", color="none")
    for i in range(len(b)):
        if whichRf[i]:
            b[i].set_lw(1)
            color = "r" if whichCl[i] else "k"
            b[i].set_edgecolor(color)
        if whichBa[i]:
            b[i].set_hatch("/")

    ticks = a.set_xticks(x_pos, labels=s.index, rotation=90)
    for i in range(len(ticks)):
        if whichRf[i]:
            color = "r" if whichCl[i] else "k"
            ticks[i].get_children()[3].set_color(color)
            # print(ticks[i].get_children())
    a.set_ylabel("Millions \$")
    a.set_title("Overall costs")

    legend = a.legend(loc="lower left",
        bbox_to_anchor=(1.0, 0.0)
    )
    a.bar_label(b, padding=-50, fmt="%.2E", rotation=90)
    f.savefig("npv.png", bbox_inches="tight")

if __name__ == "__main__":
   plot_cap_bars()
   # plot_em_bars()
   # plot_npv_bars()

