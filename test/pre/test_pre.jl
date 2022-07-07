# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################

using Test
using mid_s

include("../../src/bark/thinghys.jl")
@testset "preprocessing" begin
  file = "/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"
  T = 10
  gf = mid_s.gridForm(I)
  ta = mid_s.timeAttr(file)
  ca = mid_s.costAttr(file)
  ia = mid_s.invrAttr(file)
  sl = ia.servLife
  rf = mid_s.retrofForm(rfCaGrd,
                        rfOnMgrd, 
                        rfOnMgrd, 
                        rfHtrGrd, 
                        rfCoGrd, 
                        rfFuGrd)
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  mD = mid_s.modData(gf, ta, ca, ia, rf)
  mid_s.preProcCoef!(mD)
  @test true
end
