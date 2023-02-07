################################################################################
#                    Copyright 2022, UChicago LLC. Argonne                     #
#       This Source Code form is subject to the terms of the MIT license.      #
################################################################################
# vim: expandtab colorcolumn=80 tw=80

# created @dthierry 2022
# description: module definition for DRE4M
# log:
# 2-07-23 renaming 
#
#
#80#############################################################################

using Test
using dre4m 

@testset "model testing" begin
    pr = dre4m.prJrnl()
    jrnl = dre4m.j_start
    pr.caller = @__FILE__
    dre4m.jrnlst!(pr, jrnl)
    file = "../data/prototype/prototype_0.xlsx"
    # set form
    # time horizon
    T = 2050-2020 + 1
    # technologies
    I = 11
    

    ta = dre4m.timeAttr(file)
    ## (b) cost attributes
    ca = dre4m.costAttr(file)
    ## (c) inv(time invariant) attributes
    ia = dre4m.invrAttr(file)
    ## (d) miscellaneous
    misc = dre4m.miscParam(file)


    rtf_kinds = "B22"
    ### (b) cell (reference sheet) position for the `data for retrofits`
    rtf_data = "B28" 
    rtf = dre4m.absForm(file, rtf_kinds, rtf_data)
    ## new absract form requirements
    ### (a) cell (reference sheet) position for the `kinds of retrofits`
    nwf_kinds = "B23" # (a) cell position for the `kinds new plants`
    ### (b) cell (reference sheet) position for the `data new plants`
    nwf_data = "B29"
    nwf = dre4m.absForm(file, nwf_kinds, nwf_data)

    mS = dre4m.modSets(T, I, ia, rtf, nwf)
    # setup data
    mD = dre4m.modData(ta, ca, ia, rtf, nwf, misc)
    
    @test true
    mod = dre4m.genModel(mS, mD, pr)
    @test true
end

