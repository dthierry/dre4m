# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################


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

function xCapCost(mD::modData, baseKind::Int64, time::Int64) #: M$/GW
  #: Based on capacity.
  cA = mD.ca
  iA = mD.ia
  discount = 1/((1.e0 +iA.discountR)^time)
  return cA.capC[baseKind+1, time+1]*discount
end

function xFixCost(mD::modData, baseKind::Int64, time::Int64) #: M$/GW
  #: Does not divide by the capacity factor
  #: We could change this with the age as well.
  cA = mD.ca
  iA = mD.ia
  discount = 1/((1.e0 +iA.discountR)^time)
  return cA.fixC[baseKind+1, time+1]*discount
end
function xVarCost(mD::modData, baseKind::Int64, time::Int64) #: M$/GWh
  #: Based on generation.
  cA = mD.ca
  iA = mD.ia
  discount = 1/((1.e0 +iA.discountR)^time)
  return cA.varC[baseKind+1, time+1]*discount
end


#: (retrofit)
#: Fixed cost
function zFixCost(mD::modData, 
                  baseKind::Int64, kind::Int64, time::Int64) 
    #: M$/GW
    cA = mD.ca
    iA = mD.ia
    rfF = mD.rff
    discount = 1/((1.e0 +iA.discountR)^time)
    rmbf = mD.rmbf
    #: evaluate retrofit
    #:
    m = rmbf.mFc[(baseKind, kind)]
    b = rmbf.bFc[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end
    fixCost = multiplier * cA.fixC[baseFuel+1, time+1]
    return fixCost*discount
end

#: (retrofit)
#: Variable cost
function zVarCost(mD::modData, 
                  baseKind::Int64, kind::Int64, time::Int64) 
    #: M$/GWh
    cA = mD.ca
    iA = mD.ia
    rfF = mD.rff
    rmbf = mD.rmbf
    discount = 1/((1.e0 +iA.discountR)^time)

    #: evaluate retrofit
    #:
    m = rmbf.mVc[(baseKind, kind)]
    b = rmbf.bVc[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end

    varCost = multiplier * cA.varC[baseFuel+1, time+1]
    return varCost*discount
end

#: (retrofit)
# retrofit overnight capital cost (M$/GW)
function zCapCost(mD::modData, 
        baseKind::Int64, kind::Int64, time::Int64) 
    #: M$/GW
    cA = mD.ca
    iA = mD.ia
    rfF = mD.rff
    rmbf = mD.rmbf
    #discount = discount already comes from source
    #: evaluate retrofit
    m = rmbf.mCc[(baseKind, kind)]
    b = rmbf.bCc[(baseKind, kind)]
    (multiplier, baseFuel) = (1.e0, baseKind)
    if m >= 0
        multiplier = m
    end
    if b >= 0
        baseFuel = b
    end
    #:

    capCost = multiplier * xCapCost(mD, baseKind, time)
    # already discounted
    return capCost
end

"""
    retCostW(mD::modData, kind::Int64, time::Int64, age::Int64)
Cost of retirement.
"""
function retCostW(mD::modData, kind::Int64, time::Int64, age::Int64) 
  #: M$/GW
  cA = mD.ca
  iA = mD.ia
  discount = 1/((1.e0 +iA.discountR)^time)
  # baseAge = time - age > 0 ? time - age: 0.
  baseAge = max(time - age, 0)
  #: Loan liability
  loanFrac = max(iA.loanP - age, 0)/iA.loanP
  loanLiability = loanFrac*cA.capC[kind+1, baseAge+1] * discount
  #: Decomission
  decom = cA.decomC[kind+1] * discount
  #:
  return loanLiability + decom # lostRev*365*24
end

function saleLost(mD::modData, kind::Int64, time::Int64, age::Int64) 
  #: M$/GWh
  cA = mD.ca
  iA = mD.ia
  discount = 1/((1.e0 +iA.discountR)^time)
  effSrvLf = max(iA.servLife[kind+1] - age, 0)
  #: we need the corresponding capacity factor afterwrds
  lostRev = effSrvLf*cA.elecSaleC[time+1] * discount
  return lostRev
end


#: existing plant heat rate, (hr0) * (1+increase) ^ time
function heatRateW(mD::modData, kind::Int64, age::Int64, 
        time::Int64, maxBase::Int64)
    tA = mD.ta
    iA = mD.ia
    if age < time # this case does not exists
        return 0
    else
        baseAge = age - time
        baseAge = min(maxBase, baseAge)
        return tA.heatRw[kind+1, baseAge+1]*(1.e0+iA.heatIncR)^time
    end
end

#: (retrofit)
#: HeatRate
function heatRateZ(mD::modData, baseKind::Int64, kind::Int64, 
                   age::Int64, time::Int64, maxBase::Int64)
    tA = mD.ta
    iA = mD.ia
    rfF = mD.rff
    rmbf = mD.rmbf
    if age < time # this case does not exists
        return 0
    else
        #: evaluate retrofit
        #:
        m = rmbf.mHr[(baseKind, kind)]
        b = rmbf.bHr[(baseKind, kind)]
        (multiplier, baseFuel) = (1.e0, baseKind)
        if m >= 0
            multiplier = m
        end
        if b >= 0
            baseFuel = b
        end
        #? fuelKind
        baseAge = age - time
        baseAge = min(maxBase, baseAge)
        heatrate = (tA.heatRw[baseFuel+1, baseAge+1]*(1.e0 +iA.heatIncR)^time)
        return heatrate * multiplier
    end
end
##

function heatRateX(mD::modData, baseKind::Int64, kind::Int64, 
                   age::Int64, time::Int64)
  tA = mD.ta
  iA = mD.ia
  xDelay = mD.f.xDelay
  if time < age
    return 0
  end
  baseTime = time - age # simple as.
  baseTime = max(baseTime, 0) 
  #but actually if it's less than 0 just take 0
  return tA.heatRx[baseKind+1, baseTime+1]*(1.e0+iA.heatIncR)^time
end

#: (retrofit)
#: Carbon instance
function carbonIntW(mD::modData, baseKind::Int64, kind::Int64=-1)
  tA = mD.ta
  iA = mD.ia
  (multiplier, baseFuel) = (1.e0, baseKind)
  #:
  return iA.carbInt[baseFuel+1] * multiplier
end

#: fuel costs only include those techs that are based in fuel burning
function fuelCostW(mD::modData, baseKind::Int64, 
                   time::Int64, kind::Int64=-1)
  tA = mD.ta
  cA = mD.ca
  iA = mD.ia
  discount = 1/((1.e0 +iA.discountR)^time)
  (multiplier, baseFuel) = (1.e0, baseKind)
  return cA.fuelC[baseFuel+1, time+1]*discount 
end


#: (retrofit)
#: Carbon instance
function carbonIntZ(mD::modData, 
                    baseKind::Int64, kind::Int64=-1)
    tA = mD.ta
    iA = mD.ia
    rfF = mD.rff
    rmbf = mD.rmbf
    #: evaluate retrofit
    #:
    m = rmbf.mEm[(baseKind, kind)]
    b = rmbf.bEm[(baseKind, kind)]
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
function fuelCostZ(mD::modData, 
                   baseKind::Int64, time::Int64, kind::Int64=-1)
    tA = mD.ta
    cA = mD.ca
    iA = mD.ia
    rfF = mD.rff
    rmbf = mD.rmbf
    discount = 1/((1.e0 +iA.discountR)^time)
    #: evaluate retrofit
    m = rmbf.mFu[(baseKind, kind)]
    b = rmbf.bFu[(baseKind, kind)]
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

