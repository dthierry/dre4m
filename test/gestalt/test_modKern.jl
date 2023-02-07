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

#: test something dumb so we can see that it works
@testset "modSets" begin
    T = 5
    I = 10
    file = "../data/prototype/prototype_0.xlsx"

    ia = dre4m.invrAttr(file)

    rtf = dre4m.absForm(file, "B22", "B28")
    nwf = dre4m.absForm(file, "B23", "B29")

    ms = dre4m.modSets(T, I, ia, rtf, nwf)

    lz = 0
    lx = 0
    for i in 0:I-1 for k in 0:ms.Kz[i]-1 lz+=1 end end
    for i in 0:I-1 for k in 0:ms.Kx[i]-1 lx+=1 end end

    @test typeof(ms.I) == Int64
    @test typeof(ms.T) == Int64
    @test length(ms.Nz) == lz
    @test length(ms.Nx) == lx
end



