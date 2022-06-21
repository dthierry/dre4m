#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License, 
#############################################################################


struct gridF
  kinds_x::Vector{Int32}
  kinds_z::Vector{Int32}
  xDelay::Dict
  zDelay::Dict
end

xDelay = Dict([i => 0 for i in 0:I-1])
xDelay[techToId["PC"]] = 5
xDelay[techToId["NGCT"]] = 4
xDelay[techToId["NGCC"]] = 4
xDelay[techToId["N"]] = 10
xDelay[techToId["H"]] = 10


# Fuel for a plant at a particular year/tech/age
fuelBased = Dict(
               0 => true, # pc
               1 => true, # gt
               2 => true, # cc
               3 => true, # p
               4 => true, # b
               5 => true, # n
               6 => false, # h
               7 => false, # w
               8 => false, # s
               9 => false, # st
               10 => false # g
              )

co2Based = Dict(i=>false for i in 0:I-1)
co2Based[techToId["PC"]] = true
co2Based[techToId["NGCT"]] = true
co2Based[techToId["NGCC"]] = true
co2Based[techToId["P"]] = true
co2Based[techToId["B"]] = true



