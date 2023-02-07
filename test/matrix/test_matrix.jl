################################################################################
#                    Copyright 2022, UChicago LLC. Argonne                     #
#       This Source Code form is subject to the terms of the MIT license.      #
################################################################################
# vim: expandtab colorcolumn=80 tw=80

# created @dthierry 2022
# log:
# 2-7-23 added some comments
#
using Test
using dre4m 

file = "../data/prototype/prototype_0.xlsx"

@testset "build_timeAttr" begin
  c = dre4m.timeAttr(file)
  @test size(c.initCap) == (11, 126)
  @test size(c.nachF) == (1, 96)
  @test size(c.cFac) == (11, 78)
end


@testset "build_costAttr" begin
  c = dre4m.costAttr(file)
  @test size(c.capC) == (11, 31)
  @test size(c.varC) == (11, 31)
  @test size(c.fixC) == (11, 31)
end

@testset "build_invrAttr" begin
  c = dre4m.invrAttr(file)
  @test size(c.servLife) == (11,)
  @test size(c.carbInt) == (11,1)
  @test size(c.discountR) == ()
  @test size(c.heatIncR) == ()
end

