# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
using mid_s
using Test

@testset "modSets" begin
  T = 5
  I = 10
  sl = [i for i in 1:I]
  si = 0.01
  gf = mid_s.gridForm(I)
  for i in 0:I-1 
    gf.kinds_z[i+1] = i+1
    gf.kinds_x[i+1] = i+1
  end
  ms = mid_s.modSets(T, I, gf, sl, si)
  lz = 0
  lx = 0
  for i in 0:I-1 for k in 0:ms.Kz[i]-1 lz+=1 end end
  for i in 0:I-1 for k in 0:ms.Kx[i]-1 lx+=1 end end
  @test typeof(ms.I) == Int64
  @test typeof(ms.T) == Int64
  @test length(ms.Nz) == lz
  @test length(ms.Nx) == lx
end

@testset "testing_modData" begin
  file = "/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"
  # ta::timeAttr
  # ca::costAttr
  # ia::invrAttra
  ta = mid_s.timeAttr(file)
  ca = mid_s.costAttr(file)
  ia = mid_s.invrAttr(file)
  m = mid_s.modData(ta, ca, ia)
  @test true
end


