
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
function wFixCost(basekind, time) #: M$/GW
  #: Does not divide by the capacity factor
  #: We could change this with the age as well.
  return foam_mat[basekind+1, time+1]/((1+discountRate)^time)
end
function wVarCost(basekind, time) #: M$/GWh
  #: Based on generation.
  return voam_mat[basekind+1, time+1]/((1+discountRate)^time)
end


#: (retrofit)
#: Operation and Maintenance
#: Fixed cost
function zFixCost(baseKind, kind, time) #: M$/GW
  multiplier, baseFuel = retFitBasedCoef(baseKind, kind, time)
  fixCost = multiplier * foam_mat[baseFuel+1, time+1]
  return fixCost*discount
end
#: Variable cost
function zVarCost(baseKind, kind, time) #: M$/GW
  multiplier, baseFuel = retFitBasedCoef(baseKind, kind, time)
  varCost = multiplier * voam_mat[baseFuel+1, time+1]
  return varCost*discount
end

#: (retrofit)
# retrofit overnight capital cost (M$/GW)
function zCapCostGw(baseKind, kind, time) #: M$/GW
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

  capCost = multiplier * xCapCostGw[time, fuelKind]

  return capCost
end

function retireCostW(kind, time, age) #: M$/GW
  baseAge = time - age > 0 ? time - age: 0.
  #: Loan liability
  loanFrac = max(loan_period - age, 0)/loan_period
  loanLiability = loanFrac*cc_mat[kind+1, baseAge+1]/((1+discountRate)^t)
  #: Decomission
  decom = util_decom[kind+1, age+1]/((1+discountRate)^t)
  #:
  effSrvLf = max(serviceLife[kind+1] - age, 0)
  return loanLiability + decom # lostRev*365*24
end

function salesLostW(kind, time age) #: M$/GWh
  #: we need the corresponding capacity factor afterwrds
  lostRev = effSrvLf*util_revenues[kind+1,time+1]/((1+discountRate)^t)
  return lostRev*365*24
end


#: existing plant heat rate, (hr0) * (1+increase) ^ time
function heatRateWf(kind, age, time, maxBase)
  if age < time # this case does not exists
    return 0
  else
    baseAge = age - time
    baseAge = min(maxBase, baseAge)
    return heatRateInputMatrix[kind+1, baseAge+1] * (1+heatIncreaseRate)^time
  end
end

#: (retrofit)
#: HeatRate
function heatRateZf(baseKind, kind, age, time, maxBase)
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
    heatrate = (heatRateInputMatrix[fuelKind+1, baseAge+1] * (1+heatIncreaseRate)^time)
      return heatrate * multiplier
  end
end
##

function heatRateXf(baseKind, kind, age, time)
  if time < age
    return 0
  end
  baseTime = time - age # simple as.
  baseTime = max(baseTime - xDelay[baseKind], 0) # but actually if it's less than 0 just take 0
  return heatRateInputMatrixNew[baseKind+1, baseTime+1] * (1 + heatIncreaseRate) ^ time
end

#: (retrofit)
#: Carbon instance
function carbonIntensity(baseKind, kind=-1)
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

  return emissionRate[fuelKind+1] * multiplier
end

#: fuel costs only include those techs that are based in fuel burning
function fuelDiscounted(baseKind, time, kind=-1)
  fuelKind = baseKind
  if kind == 2
    fuelKind = 1
    if baseKind > 0
    error("basekind is more than 0")
    end
  elseif kind == 3
    fuelKind = 2
  end
  return fuel_mat[fuelKind+1, time+1] / ((1+discountRate)^time)
end

# Overnight, this should be only for new capacity (GW)
xCapCostGw = Dict()
for i in 0:I-1
  for t in 0:T-1
    xCapCostGw[t, i] = cc_mat[i+1, t+1]/((1+discountRate)^t)
    # xCapCostGw[t, i] = 
    # (cc_mat[i+1, t+1]/cfac_mat[i+1, t+1])/((1+discountRate)^t)
    # we do not want this.
  end
end
#: the cfact_mat is required here, don't ask me why.
#: should we have it?
#
