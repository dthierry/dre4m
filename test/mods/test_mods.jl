# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
using mid_s
using Test

@testset "model testing" begin
  pr = mid_s.prJnl()
  jrnl = mid_s.j_start
  pr.caller = @__FILE__
  mid_s.jrnlst!(pr, jrnl)
  
  file = "/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"
  # set form
  T = 5
  I = 10
  sl = [i for i in 1:I]
  si = 0.01
  gf = mid_s.gridForm(I)
  for i in 0:I-1 
    gf.kinds_z[i+1] = i+1
    gf.kinds_x[i+1] = i+1
  end
  # set sets
  mS = mid_s.modSets(T, I, gf, sl, si)
  # set retrofit form
  ta = mid_s.timeAttr(file)
  ca = mid_s.costAttr(file)
  ia = mid_s.invrAttr(file)
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  function rf0(base, kind, time)
    m = 1
    b = kind
    return (m, b)
  end
  fv = (b,k,t)->(3, b)
  ff = (b,k,t)->(2, 4)
  fh = (b,k,t)->(1, b)
  fe = (b,k,t)->(2, 2)
  ffu = (b,k,t)->(1, 3)
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  rf = mid_s.retrofForm(rf0, 
                        fv, 
                        ff, 
                        fh, 
                        fe, 
                        ffu)
  # set data
  mD = mid_s.modData(gf, ta, ca, ia, rf)
  @test true
  mod = mid_s.genModel(mS, mD, pr)
  @test true
end

