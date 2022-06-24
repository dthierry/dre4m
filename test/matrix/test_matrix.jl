using mid_s 
using Test

@testset "build_timeAttr" begin
  file = "/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"
  c = mid_s.timeAttr(file)
  @test typeof(c) == mid_s.timeAttr
  @test size(c.initCap) == (11, 71)
  @test size(c.nachF) == (1, 96)
  @test size(c.cFac) == (11, 96)
end


@testset "build_costAttr" begin
  file = "/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"
  c = mid_s.costAttr(file)
  @test typeof(c) == mid_s.costAttr
  @test size(c.capC) == (11, 96)
  @test size(c.varC) == (11, 96)
  @test size(c.fixC) == (11, 96)
end

@testset "build_invrAttr" begin
  file = "/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"
  c = mid_s.invrAttr(file)
  @test typeof(c) == mid_s.invrAttr
  @test size(c.servLife) == (11, 1)
  @test size(c.carbInt) == (11, 1)
  @test size(c.discountR) == ()
  @test size(c.heatIncR) == ()
end

