# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
using mid_s
using Test

#: test something dumb so we can see that it works
@testset "modSets" begin
    T = 5
    I = 10
    file = "/Users/dthierry/Projects/mid-s/data/instance_2.xlsx"

    ia = mid_s.invrAttr(file)

    rtf = mid_s.absForm(file, "B22", "B27")
    nwf = mid_s.absForm(file, "B23", "B28")

    ms = mid_s.modSets(T, I, ia, rtf, nwf)

    lz = 0
    lx = 0
    for i in 0:I-1 for k in 0:ms.Kz[i]-1 lz+=1 end end
    for i in 0:I-1 for k in 0:ms.Kx[i]-1 lx+=1 end end

    @test typeof(ms.I) == Int64
    @test typeof(ms.T) == Int64
    @test length(ms.Nz) == lz
    @test length(ms.Nx) == lx
end



