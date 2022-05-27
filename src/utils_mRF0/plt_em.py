import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize as nrm
from matplotlib.cm import ScalarMappable as smb
from matplotlib.colors import ListedColormap
from generalD import *

# the list names comes from generalID

plt.rcParams['hatch.linewidth'] = 0.2
colour_map = "tab20c"

plt.rcParams['text.usetex'] = True

def wAndXandZbarsEm(tech: int):
    """ This one plots the distribution of ages for existing and new.
    It also plots retrofits, but it only uses a single colour"""
    realName = tName[tech]
    name1 = []
    for name in namesW:
        kind = kinds[name]

        for k in range(kind[tech]):
            if name in ["w", "uw"]:
                sheet0 = name + "e_" + str(tech)
            else:
                sheet0 = name + "e_" + str(tech) + "_" + str(k)
            name1.append(sheet0)


    df = pd.DataFrame()
    em_file = getFiles("*_em.xlsx")
    print("Using file {}".format(em_file))
    for name in name1:
        d = pd.read_excel(em_file, sheet_name=name, index_col=0)
        if name == name1[0]:
            df = pd.DataFrame(d.sum(axis=1), columns=[name])
        else:
            df.insert(1, name, d.sum(axis=1))
    #
    f, a = plt.subplots(dpi=200)
    cute_names = {"we": "Existing", 
            "ze": "Retrofit",
            "xe": "New"}
    h = {
            "we": "oo",
            "ze": ".",
            "xe": "++"
            }
    d = df
    df0 = pd.Series([0 for i in df.index])
    for c in d.columns:
        bC = a.bar(d.index, d[c], 
                bottom=df0, 
                label=cute_names[c.split("_")[0]],
                #color=colour,
                alpha=0.2,
                hatch=h[c.split("_")[0]],
                #linewidth=0.1,
                )
        df0 += d[c]
    a.legend(loc=0)
    a.set_xlabel("year")
    a.set_ylabel(r"tCO$_{2}$")
    a.set_title(realName + " Emission")
    efn = em_file.split(".")[1].replace("/", "")
    f.savefig("em_tech_{}_{}.png".format(tech, efn), format="png")
    print("saved!")

def all_em():
    lenFuelBased = 0
    name1 = []
    for name in namesW:
        kind = kinds[name]
        for i in range(I):
            if not fuelKind[i]:
                continue
            for k in range(kind[i]):
                if name == "w":
                    sheet0 = name + "e_" + str(i)
                    lenFuelBased += 1
                else:
                    sheet0 = name + "e_" + str(i) + "_" + str(k)
                name1.append(sheet0)

    print(name1)
    print("Number of techs {}".format(lenFuelBased))

    norm = nrm(vmin=0, vmax=lenFuelBased)
    df = pd.DataFrame()
    em_file = getFiles("*_em.xlsx")
    print("Using file {}".format(em_file))
    for name in name1:
        d = pd.read_excel(em_file, sheet_name=name, index_col=0)
        if name == name1[0]:
            df = pd.DataFrame(d.sum(axis=1), columns=[name])
        else:
            df.insert(1, name, d.sum(axis=1))
    #
    n = nrm(vmin=1, vmax=11)
    cmap = plt.get_cmap("tab10")

    f, a = plt.subplots(dpi=200)
    cute_names = {"we": "Existing", 
            "ze": "Retrofit",
            "xe": "New"}
    h = {
            "we": "oo",
            "ze": ".",
            "xe": "++"
            }
    d = df
    df0 = pd.Series([0 for i in df.index])
    for c in name1:
        realName = tName[int(c.split("_")[1])]
        colour = cmap(
                norm(int(c.split("_")[1]))
                )
        print(c, c.split("_")[1], n(int(c.split("_")[1])+1), colour)
        bC = a.bar(d.index + 2015 + 1, d[c], 
                bottom=df0, 
                label=(cute_names[c.split("_")[0]] + " " + realName),
                color=colour,
                alpha=0.5,
                hatch=h[c.split("_")[0]],
                linewidth=0.1,
                )
        df0 += d[c]
    a.set_xlabel("year")
    l = a.legend(bbox_to_anchor=(1.0, 1.1))
    a.set_ylabel(r"tCO$_{2}$")
    a.set_title("Emission")
    a.set_ylim(0, 3e9)
    efn = em_file.split(".")[1].replace("/", "")
    f.savefig("em_all_{}.png".format(efn), format="png", bbox_inches="tight")
    print("saved!")




if __name__ == "__main__":
    all_em()
    #wAndXandZbarsEm(0)
    
