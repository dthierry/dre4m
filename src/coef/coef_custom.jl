# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################


function retFitBasedCoef(baseKind, kind, time)
  multiplier = 1.
  baseFuel = baseKind
  discount = 1/((1+discountRate)^time)
  if baseKind ∈ [0, 2] && kind == 0  #: carbon capture RF
    multiplier = carbCapOandMfact[baseKind]
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
  return mutiplier, baseFuel
end

# Operation and Maintenance (adjusted)
# (existing)
function wFixCost(mD::modData, baseKind::Int64, time::Int64) #: M$/GW
  #: Does not divide by the capacity factor
  #: We could change this with the age as well.
  cA = mD.ca
  iA = mD.ia
  return cA.fixC[baseKind+1, time+1]/((1.+iA.discountR)^time)
  #foam_mat[basekind+1, time+1]/((1+discountRate)^time)
end
function wVarCost(mD::modData, baseKind::Int64, time::Int64) #: M$/GWh
  #: Based on generation.
  cA = mD.ca
  iA = mD.ia
  return cA.varC[baseKind+1, time+1]/((1.+iA.discountR)^time)
  #voam_mat[basekind+1, time+1]/((1+discountRate)^time)
end

function xCapCost(mD::modData, baseKind::Int64, time::Int64) #: M$/GW
  #: Based on capacity.
  cA = mD.ca
  iA = mD.ia
  return cA.capC[baseKind+1, time+1]/((1.+iA.discountR)^time)
end


#: (retrofit)
#: Operation and Maintenance
#: Fixed cost
function zFixCost(mD::modData, baseKind::Int64, kind::Int64, time::Int64) 
  #: M$/GW
  cA = mD.ca
  iA = mD.ia
  multiplier, baseFuel = retFitBasedCoef(baseKind, kind, time)
  fixCost = multiplier * cA.fixC[baseFuel+1, time+1]
  return fixCost*discount
end
#: Variable cost
function zVarCost(mD::modData, baseKind::Int64, kind::Int64, time::Int64) 
  #: M$/GWh
  cA = mD.ca
  iA = mD.ia
  multiplier, baseFuel = retFitBasedCoef(baseKind, kind, time)
  varCost = multiplier * cA.varC[baseFuel+1, time+1]
  return varCost*discount
end

#: (retrofit)
# retrofit overnight capital cost (M$/GW)
function zCapCost(mD::modData, baseKind::Int64, kind::Int64, time::Int64) 
  #: M$/GW
  cA = mD.ca
  iA = mD.ia

  multiplier = 1.
  fuelKind = baseKind
  #: assume a factor of the cost of a new plant
  if baseKind ∈ [0, 2] && kind == 0 #: carbon capture
    multiplier = CarbCapFact[baseKind]
  elseif baseKind ∈ [0, 2] && kind == 1 #: efficiency
    multiplier = 0.7
  elseif baseKind ∈ [1, 3, 4] && kind == 0
    multiplier = 0.7
  end

  if baseKind == 0 && kind == 2
    multiplier = 0.5
    fuelKind = 2
  elseif baseKind == 0 && kind == 3
    multiplier = 0.5
    fuelKind = 4
  end

  capCost = multiplier * xCapCost(mD, baseKind, time)

  return capCost
end

function retireCostW(mD::modData, kind::Int64, time::Int64, age::Int64) 
  #: M$/GW
  cA = mD.ca
  iA = mD.ia
  baseAge = time - age > 0 ? time - age: 0.
  #: Loan liability
  loanFrac = max(iA.loanP - age, 0)/iA.loanP
  loanLiability = loanFrac*cA.capC[kind+1, baseAge+1]/((1+iA.discountR)^t)
  #: Decomission
  decom = cA.decomC[kind+1, age+1]/((1+iA.discountR)^t)
  #:
  effSrvLf = max(iA.servLife[kind+1] - age, 0)
  return loanLiability + decom # lostRev*365*24
end

function salesLostW(mD::modData, kind::Int64, time::Int64, age::Int64) 
  #: M$/GWh
  cA = mD.ca
  iA = mD.ia
  effSrvLf = max(iA.servLife[kind+1] - age, 0)
  #: we need the corresponding capacity factor afterwrds
  lostRev = effSrvLf*cA.elecSale[kind+1,time+1]/((1.+iA.discountR)^t)
  return lostRev*365*24
end


#: existing plant heat rate, (hr0) * (1+increase) ^ time
function heatRateW(mD::modData, kind::Int64, age::Int64, 
                    time::Int64, maxBase::Int64)
  tA = mD.ta
  iA = md.ia
  if age < time # this case does not exists
    return 0
  else
    baseAge = age - time
    baseAge = min(maxBase, baseAge)
    return tA.heatRw[kind+1, baseAge+1] * (1.+iA.heatIncR)^time
    # return heatRateInputMatrix[kind+1, baseAge+1] * (1+heatIncreaseRate)^time
  end
end

#: (retrofit)
#: HeatRate
function heatRateZ(mD::modData, baseKind::Int64, kind::Int64, 
                   age::Int64, time::Int64, maxBase::Int64)
  tA = mD.ta
  iA = md.ia
  if age < time # this case does not exists
    return 0
  else
    multiplier = 1.
    fuelKind = baseKind
    if baseKind ∈ [0, 2] && kind == 0  #: carbon capture RF
      multiplier = 1.34  # carbon capture RF
    elseif baseKind ∈ [0, 2] && kind == 1
      multiplier = 0.7  #: efficiency RF
    elseif baseKind ∈ [1, 3, 4] && kind == 0
      multiplier = 0.7  #: efficiency RF
    end
    if baseKind == 0 && kind == 2 #: Fuel RF for coal
        fuelKind = 2 # Natural gas
    elseif baseKind == 0 && kind == 3 # Fuel RF
        fuelKind = 4 # biomass
    end
    baseAge = age - time
    baseAge = min(maxBase, baseAge)
    heatrate = (tA.heatRw[fuelKind+1, baseAge+1]*(1.+iA.heatIncR)^time)
      return heatrate * multiplier
  end
end
##

function heatRateX(mD::modData, baseKind::Int64, kind::Int64, 
                   age::Int64, time::Int64)
  tA = mD.ta
  iA = md.ia
  if time < age
    return 0
  end
  baseTime = time - age # simple as.
  baseTime = max(baseTime - xDelay[baseKind], 0) # but actually if it's less than 0 just take 0
  return tA.heatRx[baseKind+1, baseTime+1] * (1 + heatIncreaseRate) ^ time
end

#: (retrofit)
#: Carbon instance
function carbonIntensity(mD::modDota, baseKind::Int64, kind::Int64=-1)
  tA = mD.ta
  iA = md.ia
  multiplier = 1.  # give or take depending on the kind
  fuelKind = baseKind
  if baseKind ∈ [0, 2] && kind == 0  #: carbon capture RF
    multiplier = 0.15  # carbon capture RF
  end

  if baseKind == 0 #: Fuel RF for coal
    if kind == 2 # Fuel RF
      fuelKind = 2 # Natural gas
    elseif kind == 3 # Fuel RF
      fuelKind = 4 # biomass
    end
  end
  return iA.carbInt[fuelKind+1] * multiplier
end

#: fuel costs only include those techs that are based in fuel burning
function fuelDiscounted(mD::modData, baseKind::Int64, 
                        time::Int64, kind::Int64=-1)
  tA = mD.ta
  cA = mD.ca
  iA = md.ia
  fuelKind = baseKind
  if kind == 2
    fuelKind = 1
    if baseKind > 0
    error("basekind is more than 0")
    end
  elseif kind == 3
    fuelKind = 2
  end
  return cA.fuelC[fuelKind+1, time+1] / ((1+iA.discountR)^time)
end

