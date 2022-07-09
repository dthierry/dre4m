# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
using Test
using mid_s


@testset "test journalist" begin
  p = mid_s.prjp()
  j = mid_s.j_start
  mid_s.jrnlst!(p, j)
  j = mid_s.j_step
  mid_s.jrnlst!(p, j)
  @test true
end
