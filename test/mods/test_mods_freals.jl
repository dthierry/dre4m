# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80 tw=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
#
using mid_s
using Test

include("../../src/bark/thinghys.jl")

@testset "foreals" begin
  pr = mid_s.prJrnl()
  jrnl = mid_s.j_start
  pr.caller = @__FILE__
  mid_s.jrnlst!(pr, jrnl)
  
  file = "/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"
  T = 10
  gf = mid_s.gridForm(I)
  # Set arbitrary (new) tech for subprocess i
  @test length(gf.kinds_x) == I
  @test length(kinds_z) == length(gf.kinds_x)
  @test length(kinds_x) == length(gf.kinds_z)
  for i in 1:I
    gf.kinds_x[i] = kinds_x[i]
    gf.kinds_z[i] = kinds_z[i]
    gf.xDelay[i-1] = xDelay[i-1]
  end
  # set retrofit form
  ta = mid_s.timeAttr(file)
  ca = mid_s.costAttr(file)
  ia = mid_s.invrAttr(file)
  #
  sl = ia.servLife
  @test typeof(sl) == Vector{Int64}
  @test length(sl) == I
  si = 0.2 # twenty percent service life increase
  # setup sets
  mS = mid_s.modSets(T, I, gf, sl, [si for j in 1:I])
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  # setup retrofitform
  rf = mid_s.retrofForm(rfCaGrd,
                        rfOnMgrd, 
                        rfOnMgrd, 
                        rfHtrGrd, 
                        rfCoGrd, 
                        rfFuGrd)
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  mD = mid_s.modData(gf, ta, ca, ia, rf)
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  mod = mid_s.genModel(mS, mD, pr) 
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  X = mod[:X]

  #@test length(X) == T * I * sum(mS.Kx[i] for i in 0:I-1) * 
  #      sum(mS.Nx[(i,k)] for i in 0:I-1 for k in 0:mS.Kx[i]-1)
  mid_s.genObj!(mod, mS, mD)
  mid_s.fixDelayed0!(mod, mS, mD)
  mid_s.gridConWind!(mod, mS, 7, Dict(8=>0.1, 9=>0.1))
  mid_s.gridConUppahBound!(mod, mS)
end
