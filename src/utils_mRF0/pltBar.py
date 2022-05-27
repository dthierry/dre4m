#!/usr/bin/python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize as nrm
from matplotlib.cm import ScalarMappable as smb
import sys, getopt

def main(argv):
    file = ""
    try:
        opts, args = getopt.getopt(argv, "hi:o:", ["ifile="])
    except getopt.GetoptError:
        print("pltBar.py -i <inputfolder>")
        sys.exit(2)
    for opt, arg in opts:
        if opt == "-h":
            print("pltBar.py -i <inputfolder>")
            sys.exit()
        elif opt in ("-i", "--file"):
            file = arg
            print("file")
            print(file)
    print(f"Input folder : {file}")
    CMAP0 = "tab20c"
    cmap = plt.get_cmap("Purples")
    norm = nrm(vmin=0.7, vmax=1.)
    
    #file = "Wed220504-011539"

    dfCost = pd.read_excel(file + "_ret_rel_t.xlsx")
    dfUret = pd.read_excel(file + "_ret_t_ucap.xlsx")
    dfProc = pd.DataFrame(0., index=[0, 1], columns=dfCost.columns)
    dfProc.iloc[0, :] = dfCost.sum(0)
    dfProc.iloc[1, :] = dfUret.sum(0)
    f, a = plt.subplots()
    base = 0.
    for t in np.linspace(0.1, 1., 10):
        c = cmap(norm(t))
        t = round(t, 2)
        for i in range(dfCost.shape[0]):
            if dfCost.loc[i, t] < 1e-08:
                continue
            a.bar(0, dfCost.loc[i, t],
                    width=dfUret.loc[i, t],
                    bottom=base, 
                    align="edge",
                    color=c,
                    edgecolor="k",
                    linewidth=1.,
                    label=dfCost.loc[i, "t"]
                    )
            base += dfCost.loc[i, t]
    a.legend()
    f.savefig("myfig.png", format="png")

    f, a = plt.subplots()
    base = 0.
    for t in np.linspace(0.1, 1., 10):
        c = cmap(norm(t))
        t = round(t, 2)
        a.bar(0, dfProc.loc[0, t],
                width=dfProc.loc[1, t],
                bottom=base,
                align="edge",
                color=c,
                edgecolor="k",
                linewidth=1.,
                label=t)
        base += dfProc.loc[0, t]
    a.legend(title="Relative retirement time")
    a.set_xlabel("Capacity (GWh)")
    a.set_ylabel("Cost (M$)")
    f.savefig("myfig2.png", format="png")

    f, a = plt.subplots(nrows=1, ncols=2, sharex="all", sharey="all", constrained_layout=True)
    df_xCost = pd.read_excel(file + "_zx_cap.xlsx", sheet_name="cost_new")
    df_xCap = pd.read_excel(file + "_zx_cap.xlsx", sheet_name="new_cap")
    xcost = df_xCost.sum(0)[1]
    xcap = df_xCap.sum(0)[1]
    print("cost {}".format(xcost), "cap {}".format(xcap))
    base = 0.
    for t in np.linspace(0.1, 1., 10):
        c = cmap(norm(t))
        t = round(t, 2)
        a[0].bar(0, dfProc.loc[0, t],
                width=dfProc.loc[1, t],
                bottom=base,
                align="edge",
                color=c,
                edgecolor="k",
                linewidth=1.,
                label=t)
        base += dfProc.loc[0, t]
    #a[0].legend(title="Relative retirement time")
    a[0].set_xlabel("(GWh)")
    a[0].set_ylabel("Cost (M$)")
    a[0].set_title("Retired Capacity")

    a[0].set_yscale("log")
    a[0].set_xscale("log")
    #a[0].ticklabel_format(axis="both", style="sci", scilimits=(-1,1))
    ax1 = a[0].inset_axes([0.25, 0.25, 0.5, 0.5])
    cb = f.colorbar(smb(norm=norm, cmap=cmap), ax=a[0], fraction=0.05)
    cb.set_label("Relative Age")
    cb.ax.locator_params(nbins=4)
    #cb.set_ticks([0, 1])
    base = 0.
    for t in np.linspace(0.1, 1., 10):
        c = cmap(norm(t))
        t = round(t, 2)
        ax1.bar(0, dfProc.loc[0, t],
                width=dfProc.loc[1, t],
                bottom=base,
                align="edge",
                color=c,
                edgecolor="k",
                linewidth=1.,
                label=t)
        base += dfProc.loc[0, t]
    x1, x2, y1, y2 = 0., dfProc.max(numeric_only=True).max() * 1.02, 0., base * 1.02
    ax1.set_xlim(x1, x2)
    ax1.set_ylim(y1, y2)
    ax1.locator_params(nbins=3)
    #ax1.set_xticklabels([])
    #ax1.set_yticklabels([])
    ax1.ticklabel_format(axis="both", style="sci", scilimits=(-1, 1))
    ax1.set_facecolor("#ebebeb")
    r, lines = a[0].indicate_inset_zoom(ax1, edgecolor="r")
    for l in lines:
        l.set(linewidth=1.0, visible=True)
    print(l)
    a[1].bar(0, xcost, width=xcap, align="edge", color="tomato", label="new cost", hatch=".")
    a[1].set_xlabel("(GWh)")
    a[1].set_ylabel("Cost (M$)")
    a[1].set_title("New Capacity")
    #a[1].ticklabel_format(axis="both", style="sci", scilimits=(-1,1))
    #a[1].set_yscale("log")
    #a[1].set_xscale("log")
    f.savefig("blocks_V1.png", format="png")


def cmapTest():
    cmap = plt.get_cmap("Purples")
    norm = nrm(0., 1.)
    for t in np.linspace(0.1, 1., 10):
        c = cmap(norm(t))
        plt.bar(0, 1, bottom=t, color=c, label=t)
    plt.legend()
    plt.show()


if __name__ == "__main__":
    main(sys.argv[1:])
    # cmapTest()


