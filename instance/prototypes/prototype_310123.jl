################################################################################
#                    Copyright 2022, UChicago LLC. Argonne                     #
#       This Source Code form is subject to the terms of the MIT license.      #
################################################################################
# vim: expandtab colorcolumn=80 tw=80

# created @dthierry 2023
# description: prototype example of how to set up a case study with the input
# excel file.
#
# log:
#  
#
#
#80#############################################################################
#: imports
import Clp
Clp.Clp_Version() #: this one is necessary sometimes in macos

using raids 
using JuMP

#80#############################################################################
function main()
    #76#########################################################################
    # initialize journalist structure
    pr = raids.prJrnl() #: initialize journalist data structure
    jrnl = raids.j_start #: journal action (does not change)
    pr.caller = @__FILE__ #: caller (does not change) 
     
    pr.tag = "_MY_TAG" #: set this to tag the results folder
    
    raids.jrnlst!(pr, jrnl) #: pass the data
    #76#########################################################################
    # data file
    file = "/Users/dthierry/Projects/raids/data/instance_2v11_b.xlsx"

    # time horizon
    T = 2050-2020 + 1
    # technologies
    I = 11

    # time Attributes
    ta = raids.timeAttr(file)
    # cost attributes
    ca = raids.costAttr(file)
    # inv(time invariant) attributes
    ia = raids.invrAttr(file)

    misc = raids.miscParam(file)
    
    # retrofit abstract form
    rtf = raids.absForm(file, "B22", "B28")
    # new absract form
    nwf = raids.absForm(file, "B23", "B29")

    # setup sets
    mS = raids.modSets(T, I, ia, rtf, nwf)
    # setup data
    mD = raids.modData(ta, ca, ia, rtf, nwf, misc)
    # generate model
    mod = raids.genModel(mS, mD, pr) 

    # generate objective with latency factor of 1e-01
    raids.genObj!(mod, mS, mD, latFact=1e-01)
    
    # Some additional constraints
    raids.gridConWind!(mod, mS, 7, Dict(8=>0.25, 9=>0.25, 10=>0.03)) #: wind-
    #: -ratio
    raids.gridConUpperBound!(mod, mS) #: upper bound on bio, nuclear and hydro
    raids.EmConBudget!(mod, mS) #: emission constraint
    
    # journal action
    jrnl = raids.j_query #: journal action (query)
    raids.jrnlst!(pr, jrnl)
    #
    
    # set linear programming solver
    set_optimizer(mod, Clp.Optimizer)
    # solve
    optimize!(mod)
    raids.jrnlst!(pr, jrnl)
    
    # write the results in the spreadsheets
    raids.writeRes(mod, mS, mD, pr)
    # last journal action
    raids.jrnlst!(pr, jrnl)
    #
    return mod, mS, mD, pr
end


if abspath(PROGRAM_FILE) == @__FILE__
  m = main()
end
