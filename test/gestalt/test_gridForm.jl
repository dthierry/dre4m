#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################


using mid_s
using Test


@testset "gridF" begin
  I = 10
  g = mid_s.gridForm(I)
  @test length(g.kinds_x) == I
  @test length(g.kinds_z) == I
  @test length(g.xDelay) == I
  @test length(g.zDelay) == I
  kfb = keys(g.fuelBased)
  kco = keys(g.co2Based)
  for i in 0:I-1
    @test i in kfb
    @test i in kco
  end
  g.fuelBased[0] = true
  g.fuelBased[1] = true
  g.co2Based[1] = true
  g.co2Based[1] = true
  @test sum(g.kinds_x) == 0
  @test sum(g.kinds_z) == 0
end

