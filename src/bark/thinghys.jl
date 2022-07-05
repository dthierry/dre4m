# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80 tw=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################

techToId = Dict()
techToId["PC"] = 0
techToId["NGCT"] = 1
techToId["NGCC"] = 2
techToId["P"] = 3
techToId["B"] = 4
techToId["N"] = 5
techToId["H"] = 6
techToId["W"] = 7
techToId["SPV"] = 8
techToId["STH"] = 9
techToId["G"] = 10
I = 11

xDelay = Dict([i => 0 for i in 0:I-1])
xDelay[techToId["PC"]] = 5
xDelay[techToId["NGCT"]] = 4
xDelay[techToId["NGCC"]] = 4
xDelay[techToId["N"]] = 10
xDelay[techToId["H"]] = 10
kinds_x = [
           1, # 0
           1, # 1
           1, # 2
           1, # 3
           1, # 4
           1, # 5
           1, # 6
           1, # 7
           1, # 8
           1, # 9
           1, # 10
          ]

kinds_z = [4, # 0
           1, # 1
           2, # 2
           1, # 3
           1, # 4
           0, # 5
           0, # 6
           0, # 7
           0, # 8
           0, # 9
           0, # 10
          ]

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



# 0 Pulverized Coal (PC)
# 1 Natural Gas (NGGT) a turbine or smth
# 2 Natural Gas (NGCC)
# 3 Petroleum (P)
# 4 Biomass (B)
# 5 Nuclear (N)
# 6 Hydroelectric (H)
# 7 On-shore wind (W)
# 8 Solar PV (SPV)
# 9 Solar Thermal (STH)
# 10 Geothermal (G)

#: coal
#: kind 0 := carbon capture
#: kind 1 := efficiency
#: kind 2 := coal --> NG
#: kind 3 := coal --> Biom
#: ngcc
#: kind 0 := carbon capture
#: kind 1 := efficiency
#: all else efficiency


#: we need ...
# rCap, rVar, rFix, rHtr, rCo, rFuel
#
# factor for carbon capture retrofit
cCcapCfact = Dict(
                0 => 0.625693161, #pc
                1 => 0.499772727, # igcc
                2 => 1.047898338
                )
function rfCaGrd(baseKind, kind, time)::Tuple{Float64, Int64}
  multiplier = 1.
  baseFuel = baseKind
  if baseKind ∈ [0, 2] && kind == 0  #: carbon capture RF
    multiplier = cCcapCfact[baseKind]
  elseif baseKind ∈ [0, 2] && kind == 1  #: efficiencty RF
    multiplier = 1.  #: cost is the same
  elseif baseKind ∈ [1, 3, 4] && kind == 0 #: efficiency RF
    multiplier = 1.
  end
  if baseKind == 0
    if kind == 2  #: fuel-switch
      baseFuel = 2
    elseif kind == 3  #: fuel-switch
      baseFuel = 4
    end
  end
  return (multiplier, baseFuel)
end
# thinking about this the retrofit could change a number of possible parameters
# from the model, say for example the capital, fixed, variable costs

# factor for fixed o&m for carbon capture
cCOnMfact = Dict(
                 0 => 2.130108424, #pc
                 1 => 1.17001519, # igcc
                 2 => 2.069083447
                 )
function rfOnMgrd(baseKind, kind, time)::Tuple{Float64, Int64}
  multiplier = 1.
  baseFuel = baseKind
  if baseKind ∈ [0, 2] && kind == 0  #: carbon capture RF
    multiplier = cCOnMfact[baseKind]
  elseif baseKind ∈ [0, 2] && kind == 1  #: efficiencty RF
    multiplier = 1.  #: cost is the same
  elseif baseKind ∈ [1, 3, 4] && kind == 0 #: efficiency RF
    multiplier = 1.
  end
  if baseKind == 0
    if kind == 2  #: fuel-switch
      baseFuel = 2
    elseif kind == 3  #: fuel-switch
      baseFuel = 4
    end
  end
  return (multiplier, baseFuel)
end

function rfHtrGrd(baseKind, kind, time)::Tuple{Float64, Int64}
  multiplier = 1.
  baseFuel = baseKind
  if baseKind ∈ [0, 2] && kind == 0  #: carbon capture RF
    multiplier = 1.34
  elseif baseKind ∈ [0, 2] && kind == 1  #: efficiencty RF
    multiplier = 0.7  #: cost is the same
  elseif baseKind ∈ [1, 3, 4] && kind == 0 #: efficiency RF
    multiplier = 0.7
  end
  if baseKind == 0
    if kind == 2  #: fuel-switch
      baseFuel = 2
    elseif kind == 3  #: fuel-switch
      baseFuel = 4
    end
  end
  return (mutiplier, baseFuel)
end

function rfCoGrd(baseKind, kind, time)::Tuple{Float64, Int64}
  multiplier = 1e0
  baseFuel = baseKind
  if baseKind ∈ [0, 2] && kind == 0  #: carbon capture RF
    multiplier = 0.15 
  end
  if baseKind == 0
    if kind == 2  #: fuel-switch
      baseFuel = 2
    elseif kind == 3  #: fuel-switch
      baseFuel = 4
    end
  end
  return (mutiplier, baseFuel)
end

function rfFuGrd(baseKind, kind, time)::Tuple{Float64, Int64}
  multiplier = 1e0
  baseFuel = baseKind
  # start indexing at 0!
  if baseKind == 0
    if kind == 2  #: fuel-switch
      baseFuel = 2 # to gas
    elseif kind == 3  #: fuel-switch
      baseFuel = 4 # to biofuel
    end
  end
  return (multiplier, baseFuel)
end
