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
import os, fnmatch, sys

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
    retro_alloc = df2.tail(1).iloc[0, 1:]

    df3 = eFile.parse(sheet_name="retro_retired", index_col=0)
    retro_retired = -1*df3.tail(1).iloc[0, 1:]

    df4 = eFile.parse(sheet_name="cap_cost_retro", index_col=0)
    cc_retro = df4.tail(1).iloc[0, 1:]

    df5 = eFile.parse(sheet_name="retro_RetCost", index_col=0)
    rc_retro = df5.tail(1).iloc[0, 1:]

    df6 = eFile.parse(sheet_name="old_RetCost", index_col=0)
    rc_old = df6.tail(1).iloc[0, 1:]

    df7 = eFile.parse(sheet_name="new_alloc", index_col=0)
    new_alloc = df7.tail(1).iloc[0, 1:]

    df8 = eFile.parse(sheet_name="cap_cost_new", index_col=0)
    cc_new = df8.tail(1).iloc[0, 1:]

    df9 = eFile.parse(sheet_name="new_RetCost", index_col=0)
    rc_new = df9.tail(1).iloc[0, 1:]

    df10 = eFile.parse(sheet_name="new_retired", index_col=0)
    new_retired = -1*df9.tail(1).iloc[0, 1:]
    #oc_retro = cc_retro + rc_retro

    y_pos = np.arange(len(old_cap_ret))

    f, a = plt.subplots(dpi=300)

    whichRf, whichCl, whichBa = whichRetrofit(old_cap_ret)
    col_edge = ["k" if whichRf[i] else "w"
                for i in range(len(old_cap_ret))]

    def modify_bars(bars):
        for i in range(len(bars)):
            if whichRf[i]:
                bars[i].set_lw(1)
                bars[i].set_edgecolor("k")

    bars = a.barh(y_pos-0.4, retro_retired,
                  align="edge",
                  height=0.4,
                  alpha=0.8,
                  color=clrl[0],
                  #edgecolor=col_edge,
                  hatch="\\",
                  label="retirements retro")
    modify_bars(bars)
    bars = a.barh(y_pos-0.4, retro_alloc,
                  align="edge",
                  height=0.4,
                  alpha=0.8,
                  color=clrl[1],
                  #edgecolor=col_edge,
                  hatch="/",
                  label="retrofits alloc")
    modify_bars(bars)
    bars = a.barh(y_pos, old_cap_ret,
                  align="edge",
                  height=0.4,
                  alpha=0.8,
                  color=clrl[2],
                  #edgecolor=col_edge,
                  label="retirements old")
    modify_bars(bars)
    bars = a.barh(y_pos, new_retired,
                  align="edge",
                  height=0.4,
                  alpha=0.8,
                  color=clrl[3],
                  left=old_cap_ret,
                  #edgecolor=col_edge,
                  label="retirements new")
    modify_bars(bars)
    bars = a.barh(y_pos, new_alloc,
                  align="edge",
                  height=0.4,
                  alpha=0.8,
                  color=clrl[4],
                  #edgecolor=col_edge,
                  hatch="..",
                  label="new alloc")
    modify_bars(bars)
    for i in range(3):
        y = y_pos[i]*4 + 4-0.6
        a.axhline(y=y, color="k", linestyle=(0, (1, 10)))
    a.axvline(x=0, color="k", linestyle="--")

    xlb = old_cap_ret.min() + new_retired.min()
    xlb = xlb if xlb < retro_retired.min() else retro_retired.min()
    xub = max(retro_alloc.max(), new_alloc.max())

    a.set_xlim((xlb*1.02, xub*1.02))

    yticks = a.set_yticks(y_pos, labels=old_cap_ret.index)

    for i in range(len(yticks)):
        if not whichRf[i]:
            yticks[i].get_children()[3].set_color("grey")

    a.set_xlabel("Allocations and Retirements (GW)")
    legend = a.legend(loc="lower left",
                      bbox_to_anchor=(1.0, 0.0))

    cost_sheets = ["cap_cost_retro", # 0
                   "cap_cost_new", # 1
                   "old_VoNm", # 2
                   "retro_VoNm", # 3
                   "new_VoNm", # 4
                   "old_FoNm", # 5
                   "retro_FoNm", # 6
                   "new_FoNm", # 7
                   "old_RetCost", # 8
                   "retro_RetCost", # 9
                   "new_RetCost", # 10
                   "old_fuel", # 11
                   "retro_fuel", # 12
                   "new_fuel" # 13]
                   ]
    i = 0
    #overall = pd.Series(np.zeros(old_cap_ret.shape[0]))
    for s in cost_sheets:
        df0 = eFile.parse(sheet_name=s, index_col=0)
        total = df0.tail(1).iloc[0, 1:]
        if i == 0:
            overall = total.copy()
        else:
            overall = overall.add(total)
        i+=1
        # print(overall)
    a1 = a.twiny()
    scat = a1.scatter(overall, y_pos, marker="d", label="NPV", c="tomato")
    scat.set_edgecolors(col_edge)
    a1.set_xlabel("Millions \$")
    a1.set_xlim(0, max(overall)*1.02)
    a1.legend()

    # axlim = a.get_xlim()
    # print(f"xlims {axlim[0]}, {axlim[1]}")
    # ax_ratio = axlim[0]/axlim[1]
    # print(f"ratio of x-axis {ax_ratio}")
    # a1.set_xlim(left=a1.get_xlim()[1]*ax_ratio)

    # a1 = a.twiny()
    # a1.barh(y_pos, cc_retro, align="center", height=0.5, left=0, color="navy",
    #         label="retro Cap cost", linewidth=1, edgecolor="k")
    # a1.barh(y_pos, rc_retro, align="center", height=0.5, left=cc_retro,
    #         color="gold", label="retro ret Cost", linewidth=1, edgecolor="k")
    # a1.set_xlabel("Millions \$")
    # a1.ticklabel_format(axis="x", style='sci', scilimits=(-3, 3))
    # a1.legend(loc=2)

    # axlim = a.get_xlim()
    # print(f"xlims {axlim[0]}, {axlim[1]}")
    # ax_ratio = axlim[0]/axlim[1]
    # print(f"ratio of x-axis {ax_ratio}")
    # a1.set_xlim(left=a1.get_xlim()[1]*ax_ratio)

    f.savefig("cap.png", bbox_inches="tight")
    f.clf()
    sys.exit()

    f, a = plt.subplots(dpi=100)


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


if __name__ == "__main__":
   plot_cap_bars()
   # plot_em_bars()
   # plot_npv_bars()

