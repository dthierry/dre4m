################################################################################
#                    Copyright 2022, UChicago LLC. Argonne                     #
#       This Source Code form is subject to the terms of the MIT license.      #
################################################################################
# vim: expandtab colorcolumn=80 tw=80

# created @dthierry 2022
# log:
# 2-7-23 added some comments



using Test
using dre4m


@testset "test journalist" begin
    p = dre4m.prJrnl()
    j = dre4m.j_start
    p.caller = @__FILE__ #: caller (does not change) 
    p.tag = "_MY_TAG" #: set this to tag the results folder
    dre4m.jrnlst!(p, j)
    j = dre4m.j_query
    dre4m.jrnlst!(p, j)
    @test true
end
