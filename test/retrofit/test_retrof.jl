# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
using mid_s
using Test

@testset "retrofit functions" begin
  function rf0(base, kind, time)
    m = 1
    b = kind
    return (m, b)
  end
  fv = (b,k,t)->(3, b)
  ff = (b,k,t)->(2, 4)
  fh = (b,k,t)->(1, b)
  fe = (b,k,t)->(2, b*2)
  ff = (b,k,t)->(1, b*3)
  rfs = mid_s.retrofForm(rf0, fv, ff, fh, fe, ff)
  @test rfs.rCap(1, 1, 1) == (1, 1)
  @test rfs.rVar(1, 2, 3) == (3, 1)
end

