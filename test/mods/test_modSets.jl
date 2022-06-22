using mid_s
using Test

@testset "modSets_bruv" begin
  time = 30
  I = 3
  kinds_z = [1, 3, 5]
  kinds_x = [1, 3, 5]
  servLife = [3, 5, 7]
  servLifeIncr = 0.1
  ms = mid_s.modSets(time, I, 
                     kinds_z, 
                     kinds_x, 
                     servLife,
                     servLifeIncr)
  k = keys(ms.Nz)
  @test typeof(ms.Nz) == Dict{Tuple{Int64, Int64}, Int64}
  @test length(ms.Kz) == I
  for i in 0:I-1 for j in 0:ms.Kz[i]-1
    @test (i, j) in k
    end
  end
end

