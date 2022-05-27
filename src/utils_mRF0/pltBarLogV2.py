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
    norm = nrm(vmin=0.0, vmax=2.)
    

    dfCostW = pd.read_excel(file + "_ret_rel_t.xlsx", sheet_name="cost_by_age")
    dfCostZ = pd.read_excel(file + "_ret_rel_t.xlsx", sheet_name="cost_by_age_rf")
    dfCostX = pd.read_excel(file + "_ret_rel_t.xlsx", sheet_name="cost_by_age_new")

    dfUretW = pd.read_excel(file + "_ret_t_ucap.xlsx", sheet_name="cap_by_age")
    dfUretZ = pd.read_excel(file + "_ret_t_ucap.xlsx", sheet_name="cap_by_age_rf")
    dfUretX = pd.read_excel(file + "_ret_t_ucap.xlsx", sheet_name="cap_by_age_new")

    dfProc = pd.DataFrame(0., index=[0, 1], columns=dfCostW.columns)
    print(dfCostW.sum(0))
    print(dfCostZ.sum(0))
    dfProc.iloc[0, :] = dfCostW.sum(0) + dfCostZ.sum(0)
    dfProc.iloc[1, :] = dfUretW.sum(0) + dfUretZ.sum(0)

    f, a = plt.subplots(nrows=1, ncols=2, sharex="all", sharey="all", constrained_layout=True)
    df_xCost = pd.read_excel(file + "_zx_cap.xlsx", sheet_name="cost_new")
    df_xCap = pd.read_excel(file + "_zx_cap.xlsx", sheet_name="new_cap")
    xcost = df_xCost.sum(0)[1]
    xcap = df_xCap.sum(0)[1]

    df_zCost = pd.read_excel(file + "_zx_cap.xlsx", sheet_name="cost_rf")
    df_zCap = pd.read_excel(file + "_zx_cap.xlsx", sheet_name="rf_cap")
    zcost = df_zCost.sum(0)[1]
    zcap = df_zCap.sum(0)[1]

    print("xcost {}".format(xcost), "xcap {}".format(xcap))
    print("zcost {}".format(zcost), "zcap {}".format(zcap))

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
                label=t, 
                hatch="/")
        base += dfProc.loc[0, t]
    #a[0].legend(title="Relative retirement time")
    a[0].set_xlabel("(GWh)")
    a[0].set_ylabel("Cost (M$)")
    a[0].set_title("Retired Capacity")
    
    a[0].set_ylim(0, 1.5e6)
    a[0].set_xlim(0, 6.5e6)
    a[0].set_yscale("log")
    a[0].set_xscale("log")
    
    #a[0].ticklabel_format(axis="both", style="sci", scilimits=(-1,1))
    cb = f.colorbar(smb(norm=norm, cmap=cmap), 
            ax=a[0], 
            fraction=0.05,
            pad=0.)
    cb.ax.set_ylim(0.0, 1.0)
    cb.set_label("Relative Age", labelpad=-5, color=cmap(norm(1)))
    cb.drawedges = True
    cb.ax.locator_params(nbins=1)
    #cb.set_ticks([0, 1])
    base = 0.
    a[1].bar(0, xcost, width=xcap, align="edge", color="tomato", label="New cost", hatch=".")
    a[1].bar(xcap, zcost, width=zcap, align="edge", color="salmon", label="Retro. cost", hatch="o")
    a[1].legend()
    a[1].set_xlabel("(GWh)")
    a[1].set_ylabel("Cost (M$)")
    a[1].set_title("New Capacity")
    #a[1].ticklabel_format(axis="both", style="sci", scilimits=(-1,1))
    #a[1].set_yscale("log")
    #a[1].set_xscale("log")
    f.savefig("blocks_VLog1a.png", format="png")


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


