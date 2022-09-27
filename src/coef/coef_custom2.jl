# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################

"""
    devCapCost()

Returns capital cost coefficient for developments, either new capacity "X" or
retrofit "R"

"""
function devCapCost(mD::modData, 
        baseKind::Int64, 
        kind::Int64, 
        time::Int64; form::String="X") #: M$/GW
    cA = mD.ca
    iA = mD.ia
    discount = 1/((1.e0 +iA.discountR)^time)
    if form != "X"
        f = mD.rtf #: retrofit
    else
        f = mD.nwf
    end
    m = f.mCc[(baseKind, kind)]
    b = f.bCc[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end
    capCost = multiplier*cA.capC[baseKind+1, time+1]*discount
    return capCost
end

"""
    devFixCost()

Returns fixed cost coefficient for developments, either new capacity "X" or
retrofit "R"

"""
function devFixCost(mD::modData, 
        baseKind::Int64, 
        kind::Int64, 
        time::Int64; form::String="X") #: M$/GW
    cA = mD.ca
    iA = mD.ia
    discount = 1/((1.e0 +iA.discountR)^time)
    if form != "X"
        f = mD.rtf #: retrofit
    else
        f = mD.nwf
    end
    m = f.mFc[(baseKind, kind)]
    b = f.bFc[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end
    fixCost = multiplier*cA.fixC[baseKind+1, time+1]*discount
    return fixCost
end

"""
    devVarCost()

Returns var cost coefficient for developments, either new capacity "X" or
retrofit "R"

"""
function devVarCost(mD::modData, 
        baseKind::Int64, 
        kind::Int64, 
        time::Int64; form::String="X") #: M$/GW
    cA = mD.ca
    iA = mD.ia
    discount = 1/((1.e0 +iA.discountR)^time)
    if form != "X"
        f = mD.rtf #: retrofit
    else
        f = mD.nwf
    end
    m = f.mVc[(baseKind, kind)]
    b = f.bVc[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end
    varCost = multiplier*cA.varC[baseKind+1, time+1]*discount
    return varCost
end

# Operation and Maintenance (adjusted)
# (existing)
function wFixCost(mD::modData, baseKind::Int64, time::Int64) #: M$/GW
    #: Does not divide by the capacity factor
    #: We could change this with the age as well.
    cA = mD.ca
    iA = mD.ia
    discount = 1/((1.e0 +iA.discountR)^time)
    return cA.fixC[baseKind+1, time+1]*discount
end
function wVarCost(mD::modData, baseKind::Int64, time::Int64) #: M$/GWh
  #: Based on generation.
  cA = mD.ca
  iA = mD.ia
  discount = 1/((1.e0 +iA.discountR)^time)
  return cA.varC[baseKind+1, time+1]*discount
end

"""
    retCost(mD::modData, kind::Int64, time::Int64, age::Int64)
Cost of retirement.
"""
function retCost(mD::modData, kind::Int64, time::Int64, age0::Int64;
        tag::String="") 
  #: M$/GW
  cA = mD.ca
  iA = mD.ia
  discount = 1/((1.e0 +iA.discountR)^time)

  #: old & retrof will have base age of (earliest), 
  # otw the year of creation for new cap
  #: for old + retro set age0 to 0
  baseAge = 0
  currentAge = time + age0
  if tag == "X"
      baseAge = age0
      currentAge = time - age0
      if currentAge < 0
          throw(DomainError(time-age0, "argument must be nonnegative"))
      end
  end
  #: Loan liability
  loanFrac = max(iA.loanP - currentAge, 0)/iA.loanP
  #: just in case we go above
  maxYr = size(cA.capC)[2]
  if baseAge > maxYr-1
      baseAge = maxYr-1
  end
  loanLiability = loanFrac*cA.capC[kind+1, baseAge+1] * discount
  #: Decomission
  decom = cA.decomC[kind+1] * discount
  return loanLiability # + decom # lostRev*365*24
end

#
function saleLost(mD::modData, kind::Int64, time::Int64, age0::Int64;
        tag::String="") 
  #: M$/GWh
  cA = mD.ca
  iA = mD.ia
  discount = 1/((1.e0+iA.discountR)^time)
  currentAge = time + age0
  if tag == "X"
      currentAge = time - age0
      if currentAge < 0
          throw(DomainError(time-age0, "argument must be nonnegative"))
      end
  end

  effSrvLf = max(iA.servLife[kind+1] - currentAge, 0)
  lostRev = effSrvLf*cA.elecSaleC[time+1] * discount
  return lostRev
end

"""
    wHeatRate()
Heat rate coefficient.
This reflects the initial age "bucket", age0
"""
#: existing plant heat rate, (hr0) * (1+increase) ^ time
function wHeatRate(mD::modData, 
        kind::Int64, 
        age0::Int64, 
        time::Int64)
    tA = mD.ta
    iA = mD.ia
    # baseAge = min(maxBase, baseAge)
    return tA.heatRw[kind+1, age0+1]*(1.e0+iA.heatIncR)^time
end

#: (retrofit)
#: HeatRate
function zHeatRate(mD::modData, 
        baseKind::Int64, 
        kind::Int64, 
        age0::Int64, 
        time::Int64)
    tA = mD.ta
    iA = mD.ia
    rtf = mD.rtf
    #: evaluate retrofit
    #:
    m = rtf.mHr[(baseKind, kind)]
    b = rtf.bHr[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end
    maxYr = size(tA.heatRx)[2]
    if age0 > maxYr-1
        age0 = maxYr-1
    end
    heatrate = (tA.heatRx[baseFuel+1, age0+1]*(1.e0 +iA.heatIncR)^time)
    return heatrate * multiplier
end
##

function xHeatRate(mD::modData, baseKind::Int64, kind::Int64, 
        age0::Int64, time::Int64)
    tA = mD.ta
    iA = mD.ia
    nwf = mD.nwf

    m = nwf.mHr[(baseKind, kind)]
    b = nwf.bHr[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end
    maxYr = size(tA.heatRx)[2]
    if age0 > maxYr-1
        age0 = maxYr-1
    end
    heatIncr = (1.e0+iA.heatIncR)^time
    return multiplier*tA.heatRx[baseFuel+1, age0+1]*heatIncr
end

#: (retrofit)
#: Carbon instance
function wCarbonInt(mD::modData, baseKind::Int64)
    iA = mD.ia
    (multiplier, baseFuel) = (1.e0, baseKind)
    #:
    return iA.carbInt[baseFuel+1] * multiplier
end

#: (retrofit)
#: Carbon instance
function devCarbonInt(mD::modData, 
        baseKind::Int64, 
        kind::Int64; form::String="X")
    iA = mD.ia
    if form != "X"
        f = mD.rtf
    else
        f = mD.nwf
    end
    #:
    m = f.mEm[(baseKind, kind)]
    b = f.bEm[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end
    return iA.carbInt[baseFuel+1] * multiplier
end

#: fuel costs only include those techs that are based in fuel burning
function wFuelCost(mD::modData, baseKind::Int64, 
        time::Int64)
    cA = mD.ca
    iA = mD.ia
    discount = 1/((1.e0+iA.discountR)^time)
    (multiplier, baseFuel) = (1.e0, baseKind)
    return cA.fuelC[baseFuel+1, time+1]*discount 
end

#: fuel costs only include those techs that are based in fuel burning
function devFuelCost(mD::modData, 
                   baseKind::Int64, 
                   kind::Int64,
                   time::Int64; form::String="X")
    tA = mD.ta
    cA = mD.ca
    iA = mD.ia
    if form != "X"
        f = mD.rtf
    else
        f = mD.nwf
    end
    discount = 1/((1.e0 +iA.discountR)^time)
    #: evaluate retrofit
    m = f.mFu[(baseKind, kind)]
    b = f.bFu[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end
    #:
    return multiplier*cA.fuelC[baseFuel+1, time+1]*discount 
end

