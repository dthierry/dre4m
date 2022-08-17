#!/usr/bin/env python
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from readExcelResults import loadExcelOveralls
from matplotlib.colors import Normalize as nrm
from generalD import *
import sys

__author__ = "David Thierry"

plt.rcParams.update({
    "text.usetex": True,
    "font.family": "serif",
    "font.serif": ["Palatino"],
})



suffix = {}
suffix["w"] = ""
suffix["z"] = "Retro."
suffix["x"] = "New"
suffix["uw"] = "Ret. old"
suffix["uz"] = "Ret. retro."
suffix["ux"] = "Ret. new"

(kinds_z, kinds_x) = loadKinds()

def export_legend(legend, filename="legend.png"):
    fig  = legend.figure
    fig.canvas.draw()
    bbox  = legend.get_window_extent().transformed(fig.dpi_scale_trans.inverted())
    fig.savefig(filename, dpi="figure", bbox_inches=bbox)

def stacksSingle(l: list, dmax: float) -> None:
    """ Generates a single stacked plot for every name """
    n = len(l["w"].columns)
    cmap = plt.get_cmap(CMAP0)
    norm = nrm(vmin=0, vmax=I*min(1, max(kinds_z)))
    for name in names:
        df = l[name]
        # format the names/labels
        if name in ["w", "uw"]:
            cNames = [col.split("_") + [""] for col in df.columns]
        else:
            cNames = [col.split("_") for col in df.columns]
        all_colours = [cmap(norm(int(cName[1]))) for cName in cNames]
        labels = [tName[int(cName[1])] + " " + suffix[name]
                for cName in cNames]
        f, a = plt.subplots(dpi=200)
        a.stackplot(df.index + 2015,
                [df[col] for col in df.columns],
                colors=all_colours,
                labels=labels,
                alpha=0.7)
        a.set_xlabel("year")
        a.set_ylabel("GW")
        a.set_ylim([0, dmax])
        a.set_title(dName[name])
        excelFileName = getFiles("*_effective.xlsx")
        efn = excelFileName.split(".")[1].replace("/", "")
        f.savefig(name + "_" + efn + "_SingleStack" + ".png", format="png")
        legend = a.legend(loc=0)
        export_legend(legend,
                "legend_" + name + "_" + efn + "_SingleStack" + ".png")


def allStacked(l: dict, dmax: float) -> None:
    all_columns = []
    all_colours = []
    all_labels = []
    all_hatches = []

    norm = nrm(vmin=0, vmax=I*min(1, max(kinds_z)))
    cmap = plt.get_cmap(CMAP0)
    # unpack the dataframes into a list of columns
    for name in namesW:
        df = l[name] #.shift(fill_value=0) if name == "z" else l[name]
        all_columns += [df[col] for col in df.columns]
        if name == "w":  # split the name into just "number, "
            nameSplits = [col.split("_")[1] for col in df.columns]
            all_labels += [tName[int(nameS)] + " " + suffix[name] for nameS in nameSplits]
            all_hatches += ["" for nameS in nameSplits]
        else:  # split it into "number, subnumber"
            nameSplits = [col.split("_")[1:] for col in df.columns]
            all_labels += [tName[int(nameS[0])] + " " + nameS[1] + " " + suffix[name] for nameS in nameSplits]
            hatch = "/" if name == "z" else ".."
            all_hatches += [hatch*(int(nameS[1]) + 1) for nameS in nameSplits]
        #all_labels += [tName[int(nameS[0])] + " " + suffix[name]
        #        for nameS in nameSplits]
        colourVal = [int(col.split("_")[1]) for col in df.columns]
        all_colours += [cmap(norm(cv)) for cv in colourVal]
    print(all_hatches)
    # Create subplots
    f, a = plt.subplots(dpi=300)
    sp = a.stackplot(
            l["w"].index + 2020,
            all_columns,
            colors=all_colours,
            labels=all_labels
            )
    for s in sp:
        s.set_edgecolor("black")
        s.set_lw(0.2)
        s.set_alpha(0.7)
    # change the hatch of each kind
    #lenW = len(l["w"].columns)
    #lenZ = len(l["z"].columns)
    #lenX = len(l["x"].columns)
    #for k in range(lenW, lenW + lenZ):
    #    sp[k].set_hatch("/")
        #sp[k].set_alpha(0.5)
    #for k in range(lenW + lenZ, lenW + lenZ + lenX):
    #    sp[k].set_hatch("..")
        #sp[k].set_alpha(0.6)

    for area, hatch in zip(sp, all_hatches):
        area.set_hatch(hatch)

    a.set_xlabel("Year")
    a.set_ylabel("GW")
    a.set_xlim(2020, 2050)
    #ax.set_ylim([0, dmax])
    #a.plot(l["demand"].index + 2015,
    #        l["demand"]["demand"], "--",
    #        lw=2, label="demand", color="crimson")
    #legend = a.legend(bbox_to_anchor=(1.0, 1.1))

    #axIn = a.inset_axes([0.5, 0.2, 0.3, 0.3])
    #sp1 = axIn.stackplot(l["w"].index + 2015,
    #        all_columns,
    #        colors=all_colours,
    #        labels=all_labels
    #        )
    #for s in sp1:
    #    s.set_edgecolor("black")
    #    s.set_alpha(0.7)
    #    s.set_lw(0.2)
    #for area, hatch in zip(sp1, all_hatches):
    #    area.set_hatch(hatch)

    #x1, x2, y1, y2 = 2025, 2027, 6.5e2, 6.8e2
    #axIn.set_xlim(x1, x2)
    #axIn.set_ylim(y1, y2)

    #axIn.set_xticklabels([])
    #axIn.set_yticklabels([])
    #a.indicate_inset_zoom(axIn, edgecolor="k")

    excelFileName = getFiles("*_effective.xlsx")
    print(excelFileName)
    efn = excelFileName.split(".")[1].replace("/", "")
    print(efn)
    f.savefig(efn +"_all.png", format="png", bbox_inches="tight")
    #legend = a.legend()

    legend = a.legend(bbox_to_anchor=(1.0, 1.1))
    f.canvas.draw()
    bbox = legend.get_window_extent().transformed(f.dpi_scale_trans.inverted())
    #legend_bbox = legend.get_tightbbox(f.canvas.get_renderer())
    #legend_bbox = legend_bbox.transformed(f.dpi_scale_trans.inverted())
    #legend_fig, legend_ax = plt.subplots(figsize=(legend_bbox.width, legend_bbox.height))

    #legend_squared = legend_ax.legend(
    #        a.get_legend_handles_labels(),
            #bbox_to_anchor=(0, 0, 1, 1),
            #bbox_transform=legend_fig.transFigure,
            #frameon=False,
            #fancybox=None,
            #shadow=False,
            #ncol=1,
            #mode='expand',
    #        )

    # Remove everything else from the legend's figure
    #legend_ax.axis('off')

    # Save the legend as a separate figure
    legend_figpath = 'graph-legend.png'
    print(f"Saving to: {legend_figpath}")
    #f.savefig(
    #    legend_figpath,
    #    bbox_inches='tight',
    #    bbox_extra_artists=[legend_squared],
    #)
    f.savefig(legend_figpath, bbox_inches=bbox)

def sBars(l: list) -> None:
    """ Generates a single bar stacked plot for every name """
    n = len(l["w"].columns)
    cmap = plt.get_cmap(CMAP0)
    norm = nrm(vmin=0, vmax=I*min(1, max(kinds_z)))
    for name in names:
        df = l[name]
        # format the names/labels
        if name in ["w", "uw"]:
            cNames = [col.split("_") + ["0"] for col in df.columns]
        else:
            cNames = [col.split("_") for col in df.columns]
        print(cNames, name)
        baseHatch = ""
        if name in ["z", "uz"]:
            baseHatch = "/"
        elif name in ["x", "ux"]:
            baseHatch = "."

        all_colours = [cmap(norm(int(cName[1]))) for cName in cNames]
        labels = [tName[int(cName[1])] + " " + suffix[name]
                for cName in cNames]
        hatches = [baseHatch*int(cName[2]) for cName in cNames]

        f, a = plt.subplots(dpi=200)

        base = pd.Series([0 for j in df.index])
        k = 0
        yu = 1e3
        for col in df.columns:
            a.bar(df.index, df[col], bottom=base,
                    color=all_colours[k],
                    label=labels[k],
                    hatch=hatches[k])
            base += df[col]
            yu = max(yu, base.max())
            k += 1
        print("{} bars stacked".format(k))
        a.set_xlabel("year")
        a.set_ylabel("GW")
        a.set_title(dName[name])
        yu = round(int(yu*1.01), -3) + 1e3
        a.set_ylim(0, yu)
        excelFileName = getFiles("*_effective.xlsx")
        efn = excelFileName.split(".")[1].replace("/", "")
        f.savefig(name + "_" + efn + "_sBarSingle" + ".png", format="png")
        legend = a.legend(loc=0)
        export_legend(legend,
                "legend_" + name + "_" + efn + "_sBarSingle" + ".png")


def main():
    l, dmax = loadExcelOveralls()
    allStacked(l, dmax)
    #stacksSingle(l, dmax)
    sBars(l)
    return l, dmax


if __name__ == "__main__":
    l, dmax = main()

