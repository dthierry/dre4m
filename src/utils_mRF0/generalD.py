import os, fnmatch
from typing import Tuple
I = 11

kinds_w = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]

fuelKind = [True, True, True, True, True, False, False, False, False, False, False]

CMAP0 = "tab20c"

#tName = ["PC", "NGGT", "NGCC" ,"P" ,"B" ,"N" ,"H" ,"W" ,"SPV" ,"STH" ,"G"]

tName = ["pc", "nggt", "ngcc" ,"p" ,"b" ,"n" ,"h" ,"w" ,"spv" ,"sth" ,"g"]
tName = [n.swapcase() for n in tName]
dName = {"w": "Existing", "z": "Retrofit", "x": "New", 
        "uw": "Ret. old", "uz": "Ret. retrof.", "ux": "Ret. new"}

greyes = ["dark grey", "battleship grey", "blue grey", 
        "cement", "charcoal grey", "brown grey", 
        "cool grey", "dark blue grey", "green grey", 
        "grey teal"]
colList = ["berry", "blood", "blueberry", "blurple", 
        "dark sky blue", "deep lavender", "butterscotch", 
        "primary blue", "cool blue", "cobalt"]

colL = greyes

names = ["w", "uw", "z", "uz", "x", "ux"]
namesW = ["w", "z", "x"]

#names0 = ["w", "uw"]
#j = 0
#for name in names[2:]:
#    names0.append(name + "_" + kinds_z[j])
#    j += 1

for i in range(len(colL)):
    colL[i] = "xkcd:" + colL[i]
hatches = ['/', '\\', '|', '-', '+', 'x', 'o', 'O', '.', '*']

# def getFiles(name, path="."):
#     for r, d, f in os.walk(path):
#         if name in f:
#             print("Using file {}".format(os.path.join(r, name)))
#             return os.path.join(r, name)
#     return None

def getFiles(pattern, path="."):
    result = []
    for root, dirs, files in os.walk(path):
        for name in files:
            if fnmatch.fnmatch(name, pattern):
                result.append(os.path.join(root, name))
                print("Using file {}".format(os.path.join(root, name)))
                return os.path.join(root, name)
    return None



def loadKinds() -> Tuple[list, list]:
    filename = getFiles("*_kinds.txt")
    kinds_z = list()
    kinds_x = list()

    with open(filename, "r") as f:
        lines = f.readlines()
        d = list()
        for l in lines:
            l = l.split()[0]
            if l == "kinds_z":
                d = kinds_z
            elif l == "kinds_x":
                d = kinds_x
            else:
                d.append(int(l))
    return (kinds_z, kinds_x)

(kinds_z, kinds_x) = loadKinds()
kinds = {}
kinds = {"z": kinds_z, "x": kinds_x, "uz": kinds_z, "ux": kinds_x, "w": kinds_w, "uw": kinds_w}


