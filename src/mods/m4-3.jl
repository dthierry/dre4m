import Clp
Clp.Clp_Version()
# attempt multi-retrofits
#using SCIP

using JuMP
import XLSX
import Dates

initialTime = Dates.now()  # to log the results, I guess
fname0 = Dates.format(initialTime, "eyymmdd-HHMMSS")
fname = fname0  # copy name
@info("Started\t$(initialTime)\n")
@info("Out files:\t$(fname)\n")
mkdir(fname)
fname = "./"*fname*"/"*fname

run(pipeline(`echo $(@__FILE__)`, stdout=fname*"_.out"))
run(pipeline(`cat $(@__FILE__)`, stdout=fname*"_.out", append=true))

inputExcel_cap_mat = 
"/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"

inputExcel = 
"/Users/dthierry/Projects/plantsAnl/data/Util_Master_Input_File.xlsx"


# Set arbitrary (new) tech for subprocess i
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
#: coal
#: kind 0 := carbon capture
#: kind 1 := efficiency
#: kind 2 := coal --> NG
#: kind 3 := coal --> Biom
#: ngcc
#: kind 0 := carbon capture
#: kind 1 := efficiency
#: all else efficiency


#
# Set cardinality
# Subprocess
I = 11

open(fname*"_kinds.txt", "w") do file
  write(file, "kinds_z\n")
  for i in 0:I-1
    write(file, "$(kinds_z[i+1])\n")
  end
  write(file, "kinds_x\n")
  for i in 0:I-1
    write(file, "$(kinds_x[i+1])\n")
  end
end


# Time horizon
T = 35 

# Age - 1, 2, 3, ....
# We can have parameters as function of the year, age

XLSX.openxlsx(inputExcel, mode="r") do xf
  s = xf["Sheet1"]
  global cap_mat = s["B3:BT13"]
  s = xf["Sheet2"]
  global avgCapFac = s["B2:L2"]
end



# Read excel file
sheet = "Nom"  # Source sheet
XLSX.openxlsx(inputExcel, mode="r", enable_cache=true) do xf
  s = xf["Nom"]
  # Capacities (MWh, f(age))
  #: We need the avg. reported CF
  # global cap_mat = s["B3:BJ13"]  #: Changed to MW

  # Age of the plant :?
  global dis_mat = s["B17:BJ27"]  #: Discard probability
  # Fuel price ($/MMBTU)
  global fuel_mat = s["B31:CS41"]

  # Capital cost ($/kW, f(time))
  global cc_mat = s["B45:CS55"]  #: Checked

  # Fixed O&M costs ($/kW-yr, f(age))
  global foam_mat = s["B59:CS69"]  #: kW-yr what is this?
  #: 1 kW-yr = 1 kWh * 24 hr * 365 days
  #: I think we just need to change its units.
  
  # Variable O&M costs ($/MWh, f(age))
  global voam_mat = s["B73:CS83"]
  # Capacity factor \in [0, 1]
  global cfac_mat = s["B101:CS111"]  #: Checked.

  # OLD Heat rate (BTU/kWh, f(age)) : this seems to be computed from the raw
  # data as a sort of weighted average of the heat rates of the different
  # plants.
  global heatRateInputMatrix = s["B157:BI167"]  #: Needs update (units)
  # heat rate for 6 ... is 0
  # NEW Heat rate (BTU/kWh, f(year)) : I don't know where this comes from.
  global heatRateInputMatrixNew = s["B87:CS97"]  #: Needs update (units)
  # hear rate for 6, 7, 8, 9, 10 is 0
  
  # LCCA $/MWh: This one involves the capital costs divided by 8760 hours,
  #: and the capacity factor.
  #: global util_techcost = s["B115:CS125"] #: Needs to be changed

  # Cent/MWh
  global util_revenues = s["B143:CS153"]  #: Needs update (units)
  
  #: $/MWh, some cost divided by the nominal size ($/MW) then scaled by 
  #: 1/(8760*cf)
  #: we need to remove the capacity factor.
  global util_decom = s["B171:BI181"]
  
  # Demand (MWh, f(year))
  #: Probably we just convert this to MW assuming 24 * 365
  global d_mat = s["B185:BJ185"]

  # Market Share
  global ms_mat = s["B190:CS200"]
  # Wind ratio
  global windRatio = s["B204:B214"]
  # change sheet
  sp = xf["Parameters"]
  # service life (years)
  global serviceLife = sp["C9:C19"]
  # Emission rate (kgCO2/MMBTU)
  global emissionRate = sp["D9:D19"]
end


#####
# PREPROCESSING OF (SOME) COEFFICIENT MATRICES
#####
#
#: Note, this block should be done in functions or something else

#: Capacity matrix
# (MW) --> (GW)
cap_mat = cap_mat./1e3

# ($/MMBTU) --> (M$/MMBTU)
fuel_mat = fuel_mat./1e6 # M$/MMBTU

# (BTU/kWh) --> (MMBTU/GWh) Same thing!
# heatRateInputMatrix = heatRateInputMatrix # to (MMBTU/GWh)
# (BTU/kWh) --> (MMBTU/GWh) Same thing!
# heatRateInputMatrixNew = heatRateInputMatrixNew # to (MMBTU/GWh)

# ($/MWh) --> (M$/GWh)
# util_techcost = util_techcost.*(1e3/1e6)
loan_period = 20

# cent/kwh = 1/100 * 1000 $/MWh
# (dollar/MWh) --> (M$/GWh)
util_revenues = util_revenues.*((1000/100)* 1e3/1e6)

# ($/MWh) --> (M$/GWh)
util_decom = util_decom.*(1e3/1e6)

# (kgCO2/MMBTU)--> (tCO2/MMBTU)
emissionRate = emissionRate./1e3

# ($/kW-yr) --> (M$/GW-yr) Same thing!
# foam_mat = foam_mat 
# kWyr --> 24*365*kWh
# kW <-- kWyr/(1 year)
foam_mat = foam_mat.*1.

# ($/MWh) --> (M$/GWh)
voam_mat = voam_mat.*(1e3/1e6) 

# ($/kW) --> (M$/GW) Same thing!
# kWh = kW * hours 
# cc_mat = cc_mat #: Checked ✅ 

# (MWh) --> (GWh)
d_mat = d_mat./1e3

# util_cfs = capacity_factors
discountRate = 0.07
tcrit = 60

# Normal heat increase with ageing?
heatIncreaseRate = 0.001

# Determine the age of plant
discard = Dict()
for i in 0:I-1
  discard[i] = serviceLife[i+1]
  #global k = 0
  #for j in dis_mat[i+1, :]
  #  if j > 0
  #    print("found at $(k)\n")
  #    discard[i] = k
  #    break
  #  end
  #  global k += 1
  #end
end

# Tech for subprocess i (retrofit)
Kz = Dict()
for i in 0:I-1
  Kz[i] = kinds_z[i + 1] # redundant?
end
# Tech for subprocess i (new)
Kx = Dict()
for i in 0:I-1
  Kx[i] = kinds_x[i + 1]
end
# Age of existing asset of age i \in I
N = Dict()
for i in 0:I-1
  N[i] = discard[i]
end

# Age of the new asset of subproc i and tech k
Nx = Dict()
for i in 0:I-1
  for k in 0:Kx[i]-1
    Nx[(i, k)] = discard[i] # assume the same, simple as
  end
end

# Consider disaggregated retrofit age
#
# Added longevity for subprocess i/tech k
Nz = Dict()
for i in 0:I-1
  for k in 0:Kz[i]-1
    Nz[i, k] = N[i] + floor(Int, discard[i] * 0.20) # assume 20%
  end
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

# factor for fixed o&m for carbon capture
carbCapOandMfact = Dict(
                    0 => 2.130108424, #pc
                    1 => 1.17001519, # igcc
                    2 => 2.069083447
                    )
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
#: (retrofit)
#: Operation and Maintenance
function zFixCost(baseKind, kind, time) #: M$/GW
  multiplier, baseFuel = retFitBasedCoef(baseKind, kind, time)
  fixCost = multiplier * foam_mat[baseFuel+1, time+1]
  return fixCost*discount
end

function zVarCost(baseKind, kind, time) #: M$/GW
  multiplier, baseFuel = retFitBasedCoef(baseKind, kind, time)
  varCost = multiplier * voam_mat[baseFuel+1, time+1]
  return varCost*discount
end


# (new)
xOandMgwh = Dict()
for i in 0:I-1
  for k in 0:Kx[i]-1
    for t in 0:T-1
      xOandMgwh[t, i, k] = wOandMgwh[t, i]
    end
  end
end

# MUSD/GWh
# perhaps x and z do not have the same values as w

currSheet = 1
XLSX.openxlsx(fname*"_costCoef.xlsx", mode="w") do xf
  sheet = xf[currSheet]
  XLSX.rename!(sheet, "oandm-MUSDperGWh")
  sheet["A1"] = "time"
  sheet["A2", dim=1] = collect(0:T-1)
  sheet["B1"] = ["tech=$(i)" for i in 0:I-1]
  for t in 0:T-1
    sheet["B"*string(t+2)] = [wOandMgwh[t, i] for i in 0:I-1]
  end
end
currSheet += 1


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
# factor for carbon capture retrofit
CarbCapFact = Dict(
                0 => 0.625693161, #pc
                1 => 0.499772727, # igcc
                2 => 1.047898338
                )

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


# MUSD/GWh
# how much does the retrofit cost?

XLSX.openxlsx(fname*"_costCoef.xlsx", mode="rw") do xf
  XLSX.addsheet!(xf)
  sheet = xf[currSheet]
  XLSX.rename!(sheet, "ocap-MUSDperGWh")
  sheet["A1"] = "time"
  sheet["A2", dim=1] = collect(0:T-1)
  sheet["B1"] = ["tech=$(i)" for i in 0:I-1]
  for t in 0:T-1
    sheet["B"*string(t+2)] = [xCapCostGw[t, i] for i in 0:I-1]
  end
end
currSheet += 1

function retCostW(kind, time, age) #: M$/GW
  baseAge = time - age > 0 ? time - age: 0.
  loanFrac = max(loan_period - age, 0)/loan_period
  loanLiability = loanFrac*cc_mat[kind+1, baseAge+1]/((1+discountRate)^t)
  decom = util_decom[kind+1, age+1]/((1+discountRate)^t)
  #:
  effSrvLf = max(serviceLife[kind+1] - age, 0)
  #: Somehow do not consider the capfactor
  lostRev = effSrvLf*util_revenues[kind+1,time+1]/((1+discountRate)^t)
  return loanLiability + decom + lostRev*365*24
end

XLSX.openxlsx(fname*"_testcostCoef.xlsx", mode="w") do xf
  cs = 1
  for i in 0:I-1
    XLSX.addsheet!(xf)
    sheet = xf[cs + i]
    XLSX.rename!(sheet, "t0-$(i)")
    sheet["A1"] = "time"
    sheet["A2", dim=1] = collect(0:T-1)
    sheet["B1"] = ["age=$(j)" for j in 0:N[i]-1]
    for t in 0:T-1
      sheet["B"*string(t+2)] = [t0[t, i, j] for j in 0:N[i]-1]
    end
  end
  cs += I
  for i in 0:I-1
    XLSX.addsheet!(xf)
    sheet = xf[cs + i]
    XLSX.rename!(sheet, "t1-$(i)")
    sheet["A1"] = "time"
    sheet["A2", dim=1] = collect(0:T-1)
    sheet["B1"] = ["age=$(j)" for j in 0:N[i]-1]
    for t in 0:T-1
      sheet["B"*string(t+2)] = [t1[t, i, j] for j in 0:N[i]-1]
    end
  end
  cs += I
  for i in 0:I-1
    XLSX.addsheet!(xf)
    sheet = xf[cs + i]
    XLSX.rename!(sheet, "t2-$(i)")
    sheet["A1"] = "time"
    sheet["A2", dim=1] = collect(0:T-1)
    sheet["B1"] = ["age=$(j)" for j in 0:N[i]-1]
    for t in 0:T-1
      sheet["B"*string(t+2)] = [t2[t, i, j] for j in 0:N[i]-1]
    end
  end

  cs += I
  for i in 0:I-1
    XLSX.addsheet!(xf)
    sheet = xf[cs + i]
    XLSX.rename!(sheet, "ret-$(i)")
    sheet["A1"] = "time"
    sheet["A2", dim=1] = collect(0:T-1)
    sheet["B1"] = ["age=$(j)" for j in 0:N[i]-1]
    for t in 0:T-1
      sheet["B"*string(t+2)] = [retireCost[t, i, j] for j in 0:N[i]-1]
    end
  end
end



currSheet = 3
XLSX.openxlsx(fname*"_costCoef.xlsx", mode="rw") do xf
  for i in 0:I-1
    XLSX.addsheet!(xf)
    sheet = xf[currSheet + i]
    XLSX.rename!(sheet, "retireC-$(i)-MUSDperGWh")
    sheet["A1"] = "time"
    sheet["A2", dim=1] = collect(0:T-1)
    sheet["B1"] = ["age=$(j)" for j in 0:N[i]-1]
    for t in 0:T-1
      sheet["B"*string(t+2)] = [retireCost[t, i, j] for j in 0:N[i]-1]
    end
  end
end
currSheet += I

# Model creation
m = Model(Clp.Optimizer)
#m = Model(SCIP.Optimizer)


# Variables
#
# existing asset (GWh)
@variable(m, w[t = 0:T, i = 0:I-1, j = 0:N[i]] >= 0)
# this goes to N just because we need to constrain z at N-1

# retired existing asset
@variable(m, uw[t = 0:T, i = 0:I-1, j = 1:N[i]-1] >= 0)
# we don't retire at year 0 or at the last year i.e \{0, N}

xDelay = Dict([i => 0 for i in 0:I-1])
xDelay[techToId["PC"]] = 5
xDelay[techToId["NGCT"]] = 4
xDelay[techToId["NGCC"]] = 4
xDelay[techToId["N"]] = 10
xDelay[techToId["H"]] = 10

maxDelay = maximum(values(xDelay))

# new asset
@variable(m, x[t = -maxDelay:T, i = 0:I-1, 
               k = 0:Kx[i]-1, j = 0:Nx[(i, k)]] >= 0)
#: made a ficticious point Nx so we can know how much is retired because it
#: becomes too old

# retired new asset
@variable(m, ux[t = 0:T, i = 0:I-1, 
                k = 0:Kx[i]-1, j = 1:Nx[(i, k)]-1] >= 0)
# can't retire at j = 0

# retrofitted asset
@variable(m, 
          z[t=0:T, i=0:I-1, k=0:Kz[i]-1, j=0:Nz[i, k]] >= 0)
#: no retrofits at age 0

#: the retrofit can't happen at the end of life of a plant, i.e., j goes from
#: 0 to N[i]-12
#: the retrofit can't happen at the beginning of life of a plant, i.e. j = 0
#: made a ficticious point Nxj so we can know how much is retired because it
#: becomes too old

@variable(m,
          zp[t = 0:T, i = 0:I-1, k = 0:Kz[i]-1, j = 1:N[i]-1] >= 0)
#: zp only goes as far as the base age N

# retired retrofit
@variable(m, 
          uz[t = 0:T, i = 0:I-1, k = 0:Kz[i]-1, j = 1:(Nz[i, k]-1)] >= 0)
# can't retire at the first year of retrofit, jk = 0
# can't retire at the last year of retrofit, i.e. jk = |Nxj| 
#: no retirements at the last age (n-1), therefore only goes to n-2

# Equations
# w0 balance0
@constraint(m, 
          wbal0[t = 0:T-1, i = 0:I-1],
          w[t+1, i, 1] == w[t, i, 0])
# can't retire stuff at the beginning, can't retrofit stuff as well
#
#
# w balance0
@constraint(m, 
          wbal[t = 0:T-1, i = 0:I-1, j = 2:N[i]],
          w[t+1, i, j] == w[t, i, j-1] 
          - uw[t, i, j-1] 
          - sum(zp[t, i, k, j-1] for k in 0:Kz[i]-1)
         )
# at j = 1 wbal0 applies instead
# we need j=N to constrain z at j = N-1, simple as

# z at age 1 balance

@constraint(m, 
            zbal0[t = 0:T-1, i = 0:I-1, k = 0:Kz[i]-1],
            z[t+1, i, k, 1] == z[t, i, k, 0]
           )

# if a plant is retrofitted, we allow one year of operation, 
# i.e. uz does not appear

# z balance
@constraint(m, 
            zbalBase[t = 0:T-1, i = 0:I-1, 
                     k=0:Kz[i]-1, j=2:N[i]],
            z[t+1, i, k, j] == 
            z[t, i, k, j-1] 
            - uz[t, i, k, j-1]
            + zp[t, i, k, j-1]
           )
#: Remaining, meaning that these are timeframes that exceed the
#: age of a normal plant, thus no zp exists. 
@constraint(m, 
            zbalRemainingE[t = 0:T-1, i = 0:I-1, 
                           k=0:Kz[i]-1, j=(N[i]+1):Nz[i, k]],
            z[t+1, i, k, j] == 
            z[t, i, k, j-1] 
            - uz[t, i, k, j-1]
           )



# x at age 0 balance
@constraint(m,
            xbal0[t = 0:T-1, i = 0:I-1, k = 0:Kx[i]-1],
            x[t+1, i, k, 1] == x[t-xDelay[i], i, k, 0]
                )
#: leading time goes here
#
for t in -maxDelay:-1
  for i in 0:I-1
    for k in 0:Kx[i]-1
      fix(x[t, i, k, 0], 0, force=true)
    end
  end
end
#=
for t in 0:T
  for i in 0:I-1
    for k in 0:Kz[i]-1
      fix(uz[t, i, k, N[i]-1], 0, force=true)
      fix(zp[t, i, k, N[i]-1], 0, force=true)
    end
  end
end
=#


# x balance
@constraint(m,
            xbal[t = 0:T-1, i = 0:I-1, k = 0:Kx[i]-1, 
                 j = 2:Nx[(i, k)]],
                 x[t+1, i, k, j] == x[t, i, k, j-1] - ux[t, i, k, j-1]
                )
# don't allow new assets to be retired at 0


# Initial age distribution
# Just assign it to the vector from excel
wij = cap_mat 

@constraint(m,
            initial_w_E[i = 0:I-1, j = 0:N[i]-1],
            w[0, i, j] == wij[i+1, j+1]
           )
@constraint(m,
            initial_w_N[t = 1:T, i = 0:I-1],
            w[0, i, N[i]] == 0
           )
# no initial plant at retirement age is allowed

# Zero out all the remaining new plants of old tech
@constraint(m,
            w_age0_E[t = 1:T, i = 0:I-1],
            w[t, i, 0] == 0
           )


@constraint(m,
            z_age0_E[t = 1:T, 
                     i = 0:I-1, 
                     k=0:Kz[i]-1],
            z[t, i, k, 0] == 0
           )


# Zero out all the initial condition of the retrofits 
@constraint(m,
            ic_zE[i=0:I-1, k=0:Kz[i]-1, 
                  j=0:Nz[i, k]-1],
            z[0, i, k, j] == 0
           )


# No retrofit at the end of life of the original plant
#@constraint(m,
#            z_end_E[t=1:T, i=0:I-1, k=0:Kz[i]-1, jk=0:Nxj[(i, k, N[i]-1)]-1],
#            z[t, i, k, N[i]-1, jk] == 0
#           )

# initial condition new plants of new tech
@constraint(m,
          initial_x[i=0:I-1, k=0:Kx[i]-1, j=0:Nx[(i, k)]-1],
          x[0, i, k, j] == 0
         )

# Effective capacity old
@variable(m, W[t=0:T-1, 
               i=0:I-1, 
               j=0:N[i]-1])
@constraint(m, W_E0[t=0:T-1, 
                    i=0:I-1],
            W[t, i, 0] == w[t, i, 0]
           )
#: they have to be split as there are no forced retirements at time = 0
@constraint(m, W_E[t=0:T-1, i=0:I-1, j=1:N[i]-1],
            W[t, i, j] == 
            w[t, i, j] 
            - uw[t, i, j] 
            - sum(zp[t, i, k, j] for k in 0:Kz[i]-1)
           )

# Effective capacity retrofit
@variable(m, 
          Z[t=0:T-1, i=0:I-1, k=0:Kz[i]-1, j=0:(Nz[i, k]-1)]
         )

@constraint(m, Z_E0[t=0:T-1, i=0:I-1, k=0:Kz[i]-1],
            Z[t, i, k,  0] == z[t, i, k, 0] 
           )


@constraint(m, Z_baseE[t=0:T-1, i=0:I-1, 
                       k=0:Kz[i]-1, j=1:N[i]-1],
            Z[t, i, k, j] == 
            z[t, i, k, j] - uz[t, i, k, j] 
            + zp[t, i, k, j]
           )

#: There are no retrofits of W after N, but we still have to track the 
#: assets
@constraint(m, Z_remainingE[t=0:T-1, i=0:I-1, 
                            k=0:Kz[i]-1, j=N[i]:(Nz[i, k]-1)],
            Z[t, i, k, j] == 
            z[t, i, k, j] - uz[t, i, k, j] 
           )

            #z[t+1, i, k, 1] == 0
# Effective capacity new
@variable(m,
          X[t=0:T-1, i=0:I-1, 
            k=0:Kx[i]-1, 
            j=0:Nx[i, k]-1] 
          )


@constraint(m, X_E0[t=0:T-1, i=0:I-1, k=0:Kx[i]-1],
            X[t, i, k, 0] == #effCapInd_x[i, k, 0] * 
            x[t-xDelay[i], i, k, 0]
           )
#: oi!, leading time needed here
#
@constraint(m, X_E[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, j=1:Nx[i, k]-1],
            X[t, i, k, j] == #effCapInd_x[i, k, j] * 
            (x[t, i, k, j] - ux[t, i, k, j])
           )
#: these are the hard questions

#: hey let's just create effective generation variables instead
#: it seems that the capacity factors are the same regardless of 
#: us having retrofits, new capacity, etc.
yrHr = 24 * 365  # hours in a year

@variable(m, Wgen[t=0:T-1, i=0:I-1, j=0:N[i]-1])
@variable(m, Zgen[t=0:T-1, i=0:I-1, k=0:Kz[i]-1, j=0:(Nz[i, k]-1)])
@variable(m, Xgen[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, j=0:(Nx[i, k]-1)])

@constraint(m, WgEq[t=0:T-1, i=0:I-1, j=0:N[i]-1], 
            Wgen[t, i, j] == YrHr * cFactW[t, i, j]  * W[t, i, j]
            )
@constraint(m, ZgEq[t=0:T-1, i=0:I-1, k=0:Kz[i]-1, j=0:Nz[i, k]-1],
            Zgen[t, i, k, j] == YrHr * cFactZ[t, i, k, j] * Z[t, i, k, j]
            )
@constraint(m, XgEq[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, j=0:Nx[i, k]-1],
            Xgen[t, i, k, j] = YrHr * cFactX[t, i, k, j] * X[t, i, k, j]
            )

# Demand (GWh)
d = Dict()
for t in 0:T-1
  d[(t, 0)] = d_mat[t+1]
end


@variable(m, sGen[t = 1:T-1, i = 0:I-1]) #: supply generated
#: Generation (GWh)
@constraint(m, sGenEq[t = 1:T-1, i = 0:I-1],
          (
          sum(Wp[t, i, j] for j in 0:N[i]-1) + 
          sum(Zp[t, i, k, j] for j in 0:(Nz[i, k]-1) 
          for k in 0:Kz[i]-1) +
          sum(Xp[t, i, k, j] for j in 0:(Nx[i, k]-1) 
          for k in 0:Kx[i]-1)
          ) ==
          sGen[t, i]
          )

# Demand
@constraint(m,
            dcCon[t = 1:T-1],
            sum(sGen[t, i] for i in 0:I-1) >= d[(t, 0)]
           )
## We might not be able to satisfy demand at t=0

@variable(m, msSlack[t=1:T-1, i=0:3] >= 0)

# Market share
#@constraint(m, ms_con[t = 10:T-1, i=0:3],
#            # old
#            sum(W[t, i, j] for j in 1:N[i]-1)
#            # retrofit
#            + sum(sum(Z[t, i, k, j] 
#                      for j in 1:Nz[i, k]-1)
#                  for k in 0:Kz[i]-1) 
#            # new
#            + sum(sum(X[t, i, k, j] for j in 0:Nx[i, k]-1) 
#                  for k in 0:Kx[i]-1)
#            >= ms_mat[i+1, t+1] * d[(t, 0)] # - msSlack[t, i]
#           )
#

# Upper bound on some new techs
upperBoundDict = Dict(
                      "B" => 1000/1e3 * 0.59, 
                      "N" => 1000/1e3 * 0.898, 
                      "H" => 1000/1e3 * 0.42)
#: Just do it directly using bounds on the damn variables

for tech in keys(upperBoundDict)
  id = techToId[tech]
  for t in 1:T-1
    for k in 0:Kx[id]-1
      #for j in 0:Nx[id, k]
      set_upper_bound(x[t, id, k, 0], upperBoundDict[tech])
      #end
    end
  end
end

# Fuel requirement for retrofit: assume it requires less
# MMBtu/(GWh)
# Row = i, column = j

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

XLSX.openxlsx(fname*"_heatRateW.xlsx", mode="w") do xf
  for i in 0:I-1
    XLSX.addsheet!(xf)
    sheet = xf[i + 1]
    XLSX.rename!(sheet, "heatRate-$(i)-MMBTUperGWh")
    sheet["A1"] = "time"
    sheet["A2", dim=1] = collect(0:T-1)
    sheet["B1"] = ["age=$(j)" for j in 0:N[i]-1]
    for t in 0:T-1
      sheet["B"*string(t+2)] = [heatRateWf(i, j, t, N[i]-1) for j in 0:N[i]-1]
    end
  end
end

XLSX.openxlsx(fname*"_heatRateZ.xlsx", mode="w") do xf
  s = 0
  for i in 0:I-1
    for k in 0:Kz[i]-1
      s += 1
      XLSX.addsheet!(xf)
      sheet = xf[s]
      XLSX.rename!(sheet, "heatRate-$(i)-$(k)-MMBTUperGWh")
      sheet["A1"] = "time"
      sheet["A2", dim=1] = collect(0:T-1)
      sheet["B1"] = ["age=$(j)" for j in 0:Nz[i, k]-1]
      for t in 0:T-1
        sheet["B"*string(t+2)] = [heatRateWf(i, j, t, N[i]-1) for j in 0:Nz[i, k]-1]
      end
    end
  end
end

xDelay = Dict([i => 0 for i in 0:I-1])

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

@variable(m, heat_w[t = 0:T-1, i = 0:I-1, j = 0:N[i]-1; fuelBased[i]])

@variable(m, 
          heat_z[t = 0:T-1, i = 0:I-1, k = 0:Kz[i]-1, j = 0:Nz[i, k]-1, 
                 ; fuelBased[i]])

@variable(m, 
          heat_x[t=0:T-1, i=0:I-1, 
                 k=0:Kx[i]-1, 
                 j=0:Nx[i, k]-1; fuelBased[i]])

# Trade in the values for actual generation. 
@constraint(m,
            heat_w_E[t=0:T-1, i=0:I-1, 
                     j=0:N[i]-1; fuelBased[i]],
            heat_w[t, i, j] == 
            Wgen[t, i, j] * heatRateWf(i, j, t, N[i]-1)
           )


@constraint(m,
            heat_z_E[t = 0:T-1, i = 0:I-1, k = 0:Kz[i]-1, 
                     j = 0:Nz[i, k]-1; fuelBased[i]],
            heat_z[t, i, k, j] == 
            Zgen[t, i, k, j] * heatRateZf(i, k, j, t, N[i]-1)
           )

@constraint(m,
            heat_x_E[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, 
                     j=0:Nx[i, k]-1; fuelBased[i]],
            heat_x[t, i, k, j] == 
            Xgen[t, i, k, j] * heatRateXf(i, k, j, t) 
           )

# Carbon emission (tCO2)
@variable(m, 
          wE[t = 0:T-1, i = 0:I-1, j = 0:N[i]-1; co2Based[i]])

@variable(m, 
          zE[t=0:T-1, i=0:I-1, k=0:Kz[i]-1, j=0:Nz[i, k]-1; co2Based[i]])

@variable(m, 
          xE[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, j=0:Nx[i, k]-1; co2Based[i]])


@constraint(m,
            e_wCon[t=0:T-1, i=0:I-1, 
                   j=0:N[i]-1; co2Based[i]],
            wE[t, i, j] == heat_w[t, i, j] * carbonIntensity(i)
           )

@constraint(m,
            e_zCon[t = 0:T-1, i = 0:I-1, k =0:Kz[i]-1, 
                   j=0:Nz[i, k]-1; co2Based[i]],
            zE[t, i, k, j] == 
            heat_z[t, i, k, j] * carbonIntensity(i, k)
           )

@constraint(m,
            e_xCon[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, 
                   j=0:Nx[i, k]-1; co2Based[i]],
            xE[t, i, k, j] == heat_x[t, i, k, j] * carbonIntensity(i)
)

# (overnight) Capital for new capacity
@variable(m, xOcap[t=0:T-1, i=0:I-1])
@constraint(m, xOcapE[t=0:T-1, i=0:I-1],
            xOcap[t, i] == sum(
                               xCapCostGw[t, i] * x[t, i, k, 0]
                               for k in 0:Kx[i]-1
                              )
           )
#: You'd need to add an additional index if you have an upgraded new capacity.

# (overnight) Capital for retrofits

@variable(m, zOcap[t=0:T-1, i=0:I-1, k=0:Kz[i]-1])
@constraint(m, zOcapE[t=0:T-1, i=0:I-1, k=0:Kz[i]-1],
            zOcap[t, i, k] == sum(
                               zCapCostGw(i, k, t) * zp[t, i, k, j]
                               for j in 1:N[i]-1 #: only related to the base age
                              )
           )


# Operation and Maintenance for existing 
#: Do we have to partition this term?
@variable(m, wFixOnM[t=0:T-1, i=0:I-1])
@variable(m, wVarOnM[t=0:T-1, i=0:I-1])
j
@constraint(m,
            wFixOnM_E[t=0:T-1, i=0:I-1],
            wFixOnM[t, i] == 
            wFixCost(i, t) * sum(W[t, i, j] for j in 0:N[i]-1)
           )

@constraint(m,
            wVarOnM_E[t=0:T-1, i=0:I-1],
            wVarOnM[t, i] == 
            wVarCost(i, t) * sum(Wgen[t, i, j] for j in 0:N[i]-1)
           )


# O and M for retrofit
@variable(m, zFixOnM[t=0:T-1, i=0:I-1])
@variable(m, zVarOnM[t=0:T-1, i=0:I-1])

@constraint(m,
            zFixOnM_E[t=0:T-1, i=0:I-1],
            zFixOnM[t, i] == 
            sum(zFixCost(i, k, t) * Z[t, i, k, j] 
                  for k in 0:Kz[i]-1 
                  for j in 0:N[i]-1 #: only related to the base age
                  ))

@constraint(m,
            zVarOnM_E[t=0:T-1, i=0:I-1],
            zVarOnM[t, i] == 
            sum(zVarCost(i, k, t) * Zgen[t, i, k, j] 
                  for k in 0:Kz[i]-1 
                  for j in 0:N[i]-1 #: only related to the base age
                  ))


# O and M for new
@variable(m, xFixOnM[t=0:T-1, i=0:I-1])
@variable(m, xVarOnM[t=0:T-1, i=0:I-1])

@constraint(m,
            xFixOnM_E[t=0:T-1, i=0:I-1],
            xFixOnM[t, i] == 
            sum(xFixCost(i, t) * X[t, i, k, j] 
                for k in 0:Kx[i]-1 
                for j in 0:Nx[i, k]-1)
           )

@constraint(m,
            xVarOndM_E[t=0:T-1, i=0:I-1],
            xVarOnM[t, i] == 
            sum(xVarCost(i, t) * Xgen[t, i, k, j] 
                for k in 0:Kx[i]-1 
                for j in 0:Nx[i, k]-1)
           )

# Fuel
@variable(m, wFuelC[t=0:T-1, i=0:I-1; fuelBased[i]])

@variable(m, zFuelC[t=0:T-1, i=0:I-1; fuelBased[i]])

@variable(m, xFuelC[t=0:T-1, i=0:I-1; fuelBased[i]])
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

@constraint(m, wFuelC_E[t=0:T-1, i=0:I-1; fuelBased[i]],
            wFuelC[t, i] == 
            fuelDiscounted(i, t) * sum(heat_w[t, i, j]
                              for j in 0:N[i]-1) 
           )

@constraint(m, zFuelC_E[t=0:T-1, i=0:I-1; fuelBased[i]],
            zFuelC[t, i] == 
            sum(fuelDiscounted(i, t, k) * heat_z[t, i, k, j]
            for k in 0:Kz[i]-1 for j in 0:Nz[i, k]-1)
           )

@constraint(m, xFuelC_E[t=0:T-1, i=0:I-1; fuelBased[i]],
            xFuelC[t, i] == 
            fuelDiscounted(i, t) * sum(heat_x[t, i, k, j] 
                                              for k in 0:Kx[i]-1
                                              for j in 0:Nx[i, k]-1
                                             )
           )

@variable(m, 
          co2OverallYr[t=0:T-1]
          #1.49E+11 * 0.7
         )
# <= 6.71E+10 * 0.7)
# <=6.71E+10 * 0.7)

@constraint(m, co2OverallYrE[t=0:T-1],
            co2OverallYr[t] == 
            sum(wE[t, i, j] for i in 0:I-1 
                for j in 0:N[i]-1 if co2Based[i])
           + sum(zE[t, i, k, j] 
               for i in 0:I-1 
               for k in 0:Kz[i]-1 
               for j in 0:Nz[i, k]-1 
               if co2Based[i])
           + sum(xE[t, i, k, j] 
                 for i in 0:I-1 
                 for k in 0:Kx[i]-1 
                 for j in 0:Nx[i, k]-1 if co2Based[i])
           )

co22010 = 2.2584E+09
co2_2010_2015 = 10515700000.0
co22015 = co22010 - co2_2010_2015
co22050 = co22010 * 0.29

@constraint(m, co2Budget,
            sum(co2OverallYr[t] for t in 0:T-1)  <= 
            (co22010 + co22050) * 0.5 * 41 - co2_2010_2015
           )

@info("The budget: $((co22010 + co22050) * 0.5 * 41 - co2_2010_2015)")
#: Last term is a trapezoid minus the 2010-2015 gap


# Natural "organic" retirement
@variable(m, wOldRet[t=1:T-1, i=0:I-1])
@variable(m, zOldRet[t=1:T-1, i=0:I-1, k=0:Kz[i]-1])
@variable(m, xOldRet[t=1:T-1, i=0:I-1, k=0:Kx[i]-1])

@constraint(m, wOldRetE[t=1:T-1, i=0:I-1],
            wOldRet[t, i] == 
            retCostW(t, i, N[i]-1) * w[t, i, N[i]]
           )

@constraint(m, zOldRetE[t=1:T-1, i=0:I-1, k=0:Kz[i]-1],
            zOldRet[t, i, k] == 
            retCostW(t, i, N[i]-1) * z[t, i, k, Nz[i, k]]
           )


@constraint(m, xOldRetE[t=1:T-1, i=0:I-1, k=0:Kx[i]-1],
            xOldRet[t, i, k] == 
            retCostW(t, i, Nx[i, k]-1) * x[t, i, k, Nx[i, k]]
           )

# "Forced" retirement
@variable(m, wRet[i=0:I-1, j=1:N[i]-1])
@variable(m, zRet[i=0:I-1, k=0:Kz[i]-1, j=1:Nz[(i, k)]-1])
@variable(m, xRet[i=0:I-1, k=0:Kx[i]-1, j=1:Nx[(i, k)]-1])

@constraint(m, wRet_E[i=0:I-1, j=1:N[i]-1],
            wRet[i, j] == sum(retCostW(i, t, j) * uw[t, i, j] for t in 0:T-1)
           )

@constraint(m, zRet_E[i=0:I-1, k=0:Kz[i]-1, j=1:Nz[(i,k)]-1],
            zRet[i, k, j] 
            == sum(retCostW(i, t, min(j, N[i]-1)) * uz[t, i, k, j] 
            for t in 0:T-1)
            )


@constraint(m, xRet_E[i=0:I-1, k=0:Kx[i]-1, j=1:Nx[(i, k)]-1],
            xRet[i, k, j] == sum(retCostW(i, t, j) * ux[t, i, k, j]
            for t in 0:T-1)
           )

# Net present value
@variable(m, npv) # ≥ 1000. * 2000.)
@constraint(m, npv_e, 
            npv == 
            # overnight
            sum(
              zOcap[t, i, k]
              for t in 0:T-1
              for i in 0:I-1
              for k in 0:Kz[i]-1
              )
              +
            sum(
                xOcap[t, i]
                for t in 0:T-1
                for i in 0:I-1
               )
            # op and maintenance (fixed + variable)
            #: existing
            + sum(
                wFixOnM[t, i] + wVarOnM[t, i]
                 for t in 0:T-1 
                 for i in 0:I-1)
                 +
            #: retrofit
            + sum(
                zFixOnM[t, i] + zVarOnM[t, i]
                for t in 0:T-1
                for i in 0:I-1
                )
            #: new
            + sum(
                xFixOnM[t, i] + xVarOnM[t, i]
                for t in 0:T-1
                for i in 0:I-1
            )
            # cost of fuel
            + sum(
                  wFuelC[t, i] 
                  + zFuelC[t, i] 
                  + xFuelC[t, i] 
                  for t in 0:T-1 
                  for i in 0:I-1 if fuelBased[i]
                 )
            + sum(
                  wOldRet[t, i]
                  for t in 1:T-1
                  for i in 0:I-1
                 )
            + sum(
                  zOldRet[t, i, k]
                  for t in 1:T-1
                  for i in 0:I-1
                  for k in 0:Kz[i]-1)
            + sum(
                  xOldRet[t, i, k]
                  for t in 1:T-1
                  for i in 0:I-1
                  for k in 0:Kx[i]-1
                 )
            + sum(wRet[i, j] 
                  for i in 0:I-1 
                  for j in 1:N[i]-1
            )
            + sum(zRet[i, k, j]
                  for i in 0:I-1
                  for k in 0:Kz[i]-1
                  for j in 1:Nz[(i, k)]-1
                  )
            + sum(xRet[i, k, j]
                  for i in 0:I-1
                  for k in 0:Kx[i]-1
                  for j in 1:Nx[(i, k)]-1
                  )
           )


# Terminal cost
@variable(m, termCw[i=0:I-1, j=0:N[i]-1])

@variable(m, termCx[i=0:I-1,
                    k=0:Kx[i],
                    j=0:N[i]-1])

@variable(m, termCz[i=0:I-1, k=0:Kz[i]-1, 
                    j=0:Nz[i, k]-1])

@constraint(m, termCwE[i=0:I-1, j=0:N[i]-1],
            termCw[i, j] == retireCost[T-1, i, j] * W[T-1, i, j] 
           )

@constraint(m, termCxE[i=0:I-1, k=0:Kx[i]-1, 
                       j=0:Nx[i,k]-1],
            termCx[i, k, j] == retireCost[T-1, i, j] * X[T-1, i, k, j]
           )

@constraint(m, termCzE[i=0:I-1, k=0:Kz[i]-1, 
                       j=0:Nz[i, k]-1],
            termCz[i, k, j] == 
            retireCost[T-1, i, min(j, N[i]-1)] * Z[T-1, i, k, j]
           )

@variable(m, termCost >= 0)
@constraint(m, termCost ==
            sum(termCw[i, j] 
                for i in 0:I-1 
                for j in 0:N[i]-1)
            + sum(termCx[i, k, j]
                  for i in 0:I-1
                  for k in 0:Kx[i]-1
                  for j in 0:Nx[i, k]-1)
            + sum(termCz[i, k, j]
                  for i in 0:I-1
                  for k in 0:Kz[i]-1
                  for j in 1:Nz[i, k]-1)
           )

windIdx = 7

@constraint(m, windRatioI[t=1:T-1, i = 8:10],
            sum(X[t, i, k, 0] 
               for k in 0:Kx[i]-1
              )
            == 
            sum(X[t, windIdx, k, 0] * windRatio[i + 1]
                for k in 0:Kx[windIdx]-1
                ))
#: only applied on new allocations


@objective(m, Min, (npv
                   #+ 50/1e6 * co2Overall
                   #sum(co2OverallYr[t] for t in 0:T-1) #+
                   #1e-06 * sum(
                   #     xOcap[t, i]
                   #     for t in 0:T-1
                   #     for i in 0:I-1
                   #)
                   + (1e-6)* termCost
                   #+ 1e-3 * sum(msSlack)
                   )/1e3
          )


optimize!(m)

@info("objective\t$(objective_value(m))\n")

finalTime = Dates.now()  # to log the results, I guess
@info("End optimization\t$(finalTime)\n")

printstyled(solution_summary(m), color=:magenta)


@info("Writing xlsx files.\n")

XLSX.openxlsx(fname*"_stocks.xlsx", mode="w") do xf
  sh = 0
  for i in 0:I-1
    global sh += 1
    XLSX.addsheet!(xf)
    sheet = xf[sh]
    XLSX.rename!(sheet, "w_"*string(i))
    sheet["A1"] = "time"
    #sheet["B1"] = "i = PC"
    sheet["C1"] = ["age=$(j)" for j in 0:N[i]-1]
    sheet["A2", dim=1] = collect(0:T)
    #sheet["B2", dim=1] = [1 for i in 0:T]
    for t in 0:T
      ts = string(t + 2)
      sheet["C"*ts] = [value(w[t, i, j]) for j in 0:N[i]-1]
    end

    global sh += 1
    XLSX.addsheet!(xf)
    sheet = xf[sh]
    XLSX.rename!(sheet, "uw_"*string(i))
    sheet["A1"] = "time"
    #sheet["B1"] = "i = PC"
    sheet["C1"] = ["elmAge=$(j)" for j in 1:N[i]-1]
    sheet["A2", dim=1] = collect(0:T)
    #sheet["B2", dim=1] = [1 for i in 0:T]
    for t in 0:T
      ts = string(t + 2)
      sheet["C"*ts] = [value(uw[t, i, j]) for j in 1:N[i]-1]
    end
    for k in 0:Kz[i]-1
      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "z_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      sheet["C1"] = ["rtfAge=$(j)" for j in 0:(Nz[i, k]-1)]
      sheet["A2", dim=1] = collect(0:T)
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(z[t, i, k, j]) for j in 0:(Nz[i, k]-1)]
      end

      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "uz_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      #sheet["B1"] = "i = PC"
      sheet["C1"] = ["elRfAge=$(j)" for j in 1:Nz[i, k]-1]
      sheet["A2", dim=1] = collect(0:T)
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(uz[t, i, k, j]) for j in 1:(Nz[i, k]-1)]
      end
    end
    for k in 0:Kx[i]-1
      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "x_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      # sheet["B1"] = "i = PC"
      sheet["C1"] = ["newAge=$(j)" for j in 0:Nx[i,k]-1]
      sheet["A2", dim=1] = collect(0:T)
      # sheet["B2", dim=1] = [1 for i in 0:T]
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(x[t, i, k, j]) for j in 0:Nx[i,k]-1]
      end

      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "ux_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      # sheet["B1"] = "i = PC"
      sheet["C1"] = ["eNwAge=$(j)" for j in 1:Nx[i,k]-1]
      sheet["A2", dim=1] = collect(0:T)
      # sheet["B2", dim=1] = [1 for i in 0:T]
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(ux[t, i, k, j]) for j in 1:Nx[i,k]-1]
      end
    end
  end

  global sh += 1
  XLSX.addsheet!(xf)
  sheet = xf[sh]
  XLSX.rename!(sheet, "d")
  sheet["A1"] = "time"
  sheet["B1"] = "demand"
  sheet["A2", dim=1] = collect(0:T)
  sheet["B2", dim=1] = [d[(t, 0)] for t in 0:T-1]
end

@info("Written.\n")

XLSX.openxlsx(fname*"_em.xlsx", mode="w") do xf
  global sh = 0
  for i in 0:I-1
    if !co2Based[i]
      continue
    end
    global sh += 1
    XLSX.addsheet!(xf)
    sheet = xf[sh]
    XLSX.rename!(sheet, "we_"*string(i))
    sheet["A1"] = "time"
    sheet["B1"] = ["age=$(j)" for j in 0:N[i]-1]
    sheet["A2", dim=1] = collect(0:T-1)
    for t in 0:T-1
      ts = string(t + 2)
      sheet["B"*ts] = [value(wE[t, i, j]) for j in 0:N[i]-1]
    end
    for k in 0:Kz[i]-1
    global sh += 1
    XLSX.addsheet!(xf)
    sheet = xf[sh]
    XLSX.rename!(sheet, "ze_"*string(i)*"_"*string(k))
    sheet["A1"] = "time"
    sheet["B1"] = ["rtfAge=$(j)" for j in 0:(Nz[i, k]-1)]
    sheet["A2", dim=1] = collect(0:T-1)
    for t in 0:T-1
      ts = string(t + 2)
      sheet["B"*ts] = [value(zE[t, i, k, j]) for j in 0:(Nz[i, k]-1)]
    end
    end
    for k in 0:Kx[i]-1
    global sh += 1
    XLSX.addsheet!(xf)
    sheet = xf[sh]
    XLSX.rename!(sheet, "xe_"*string(i)*"_"*string(k))
    sheet["A1"] = "time"
    sheet["B1"] = ["newAge=$(j)" for j in 0:Nx[i,k]-1]
    sheet["A2", dim=1] = collect(0:T)
    for t in 0:T-1
      ts = string(t + 2)
      sheet["B"*ts] = [value(xE[t, i, k, j]) for j in 0:Nx[i,k]-1]
    end
  end
  end
end

@info("Written.\n")

XLSX.openxlsx(fname*"_effective.xlsx", mode="w") do xf
  sh = 0
  for i in 0:I-1
    global sh += 1
    XLSX.addsheet!(xf)
    sheet = xf[sh]
    XLSX.rename!(sheet, "w_"*string(i))
    sheet["A1"] = "time"
    #sheet["B1"] = "i = PC"
    sheet["C1"] = ["age=$(j)" for j in 0:N[i]-1]
    sheet["A2", dim=1] = collect(0:T)
    #sheet["B2", dim=1] = [1 for i in 0:T]
    for t in 0:T-1
      ts = string(t + 2)
      sheet["C"*ts] = [value(W[t, i, j]) for j in 0:N[i]-1]
    end

    global sh += 1
    XLSX.addsheet!(xf)
    sheet = xf[sh]
    XLSX.rename!(sheet, "uw_"*string(i))
    sheet["A1"] = "time"
    #sheet["B1"] = "i = PC"
    sheet["C1"] = ["elmAge=$(j)" for j in 1:N[i]-1]
    sheet["A2", dim=1] = collect(0:T)
    #sheet["B2", dim=1] = [1 for i in 0:T]
    for t in 0:T-1
      ts = string(t + 2)
      sheet["C"*ts] = [value(uw[t, i, j]) for j in 1:N[i]-1]
    end
    for k in 0:Kz[i]-1
      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "z_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      sheet["C1"] = ["rtfAge=$(j)" for j in 0:Nz[i, k]-1]
      sheet["A2", dim=1] = collect(0:T)
      for t in 0:T-1
        ts = string(t + 2)
        sheet["C"*ts] = [value(Z[t, i, k, j]) for j in 0:Nz[i, k]-1]
      end

      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "uz_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      #sheet["B1"] = "i = PC"
      sheet["C1"] = ["elRfAge=$(j)" for j in 1:Nz[i, k]-1]
      sheet["A2", dim=1] = collect(0:T)
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(uz[t, i, k, j]) for j in 1:Nz[i, k]-1]
      end
    end
    for k in 0:Kx[i]-1
      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "x_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      # sheet["B1"] = "i = PC"
      sheet["C1"] = ["newAge=$(j)" for j in 0:Nx[i,k]-1]
      sheet["A2", dim=1] = collect(0:T)
      # sheet["B2", dim=1] = [1 for i in 0:T]
      for t in 0:T-1
        ts = string(t + 2)
        sheet["C"*ts] = [value(X[t, i, k, j]) for j in 0:Nx[i,k]-1]
      end

      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "ux_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      # sheet["B1"] = "i = PC"
      sheet["C1"] = ["eNwAge=$(j)" for j in 1:Nx[i,k]-1]
      sheet["A2", dim=1] = collect(0:T)
      # sheet["B2", dim=1] = [1 for i in 0:T]
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(ux[t, i, k, j]) for j in 1:Nx[i,k]-1]
      end
    end
  end

  global sh += 1
  XLSX.addsheet!(xf)
  sheet = xf[sh]
  XLSX.rename!(sheet, "d")
  sheet["A1"] = "time"
  sheet["B1"] = "demand"
  sheet["A2", dim=1] = collect(0:T)
  sheet["B2", dim=1] = [d[(t, 0)] for t in 0:T-1]
end

XLSX.openxlsx(fname*"_stats.xlsx", mode="w") do xf
  sh = 0
  sheet = xf[1]
  XLSX.rename!(sheet, "stats")
  sheet["A1"] = "timing"
  sheet["A2"] = "objective"
  sheet["A3"] = "npv"
  sheet["A4"] = "retire"
  sheet["A5"] = "terminal"
  sheet["A6"] = "emissions"
  sheet["A7"] = "filename"
  
  sheet["B1"] = solve_time(m)
  sheet["B2"] = objective_value(m)
  sheet["B3"] = value(npv)
  sheet["B4"] = sum(value(wRet[i, j]) for i in 0:I-1 for j in 1:N[i]-1) + sum(value(zRet[i, k, j])  for i in 0:I-1 for k in 0:Kz[i]-1 for j in 1:Nz[(i, k)]-1) + sum(value(xRet[i, k, j]) for i in 0:I-1 for k in 0:Kx[i]-1 for j in 1:Nx[(i, k)]-1)
  sheet["B5"] = value(termCost)
  sheet["B6"] = sum(value(co2OverallYr[t]) for t in 0:T-1)
  sheet["B7"] = fname0
end
shl = 0
XLSX.openxlsx(fname*"_zp.xlsx", mode="w") do xf
  shl = 0
  for i in 0:I-1
    for k in 0:Kz[i]-1
      global shl += 1
      XLSX.addsheet!(xf)
      sheet = xf[shl]
      XLSX.rename!(sheet, "zp_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      #sheet["B1"] = "i = PC"
      sheet["C1"] = ["elRfAge=$(j)" for j in 1:N[i]-1]
      sheet["A2", dim=1] = collect(0:T)
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(zp[t, i, k, j]) for j in 1:N[i]-1]
      end
    end
  end
end

XLSX.openxlsx(fname*"_ret.xlsx", mode="w") do xf
  global sh = 0
  for i in 0:I-1
    global sh += 1
    XLSX.addsheet!(xf)
    sheet = xf[sh]
    XLSX.rename!(sheet, "w_"*string(i))
    sheet["A1"] = "time"
    sheet["C1"] = ["age=$(j)" for j in 1:N[i]-1]
    sheet["C2"] = [value(wRet[i, j]) for j in 1:N[i]-1]

    for k in 0:Kz[i]-1
      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "z_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      sheet["C1"] = ["rtfAge=$(j)" for j in 1:Nz[i, k]-1]
      sheet["C2"] = [value(zRet[i, k, j]) for j in 1:Nz[i, k]-1]

    end
    for k in 0:Kx[i]-1
      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "x_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      sheet["C1"] = ["newAge=$(j)" for j in 1:Nx[i,k]-1]
      sheet["C2"] = [value(xRet[i, k, j]) for j in 1:Nx[i,k]-1]

    end
  end

end

XLSX.openxlsx(fname*"_ret_1.xlsx", mode="w") do xf
  row = 2
  sheet = xf[1]
  XLSX.rename!(sheet, "cost_by_age")
  sheet["A1"] = "time"
  max_age = [maximum(values(N)), maximum(values(Nz)), maximum(values(Nx))]
  max_age = maximum(max_age)
  max_age = max_age
  sheet["B1"] = [j for j in 1:max_age-1]
  for i in 0:I-1
    #: Existing
    sheet["A$(row)"] = "w_$(i)"
    sheet["B$(row)"] = [value(wRet[i, j]) for j in 1:N[i]-1]
    row += 1
    #: RF
    for k in 0:Kz[i]-1
      sheet["A$(row)"] = "z_$(i)_$(k)"
      sheet["B$(row)"] = [value(zRet[i, k, j]) for j in 1:Nz[i, k]-1]
      row += 1
    end
    #: New
    for k in 0:Kx[i]-1
      sheet["A$(row)"] = "x_$(i)_$(k)"
      sheet["B$(row)"] = [value(xRet[i, k, j]) for j in 1:Nx[i,k]-1]
      row += 1
    end
  end
end


function relTimeClass(lVals, relTimes)
  if sum(lVals) < 1e-08
    return Dict(t => 0.0 for t in range(0.1, 1, 10))
  end
  #relVal = lVals./sum(lVals)
  relVal = lVals
  tRank = Dict()
  j = 1
  for time in range(0.1, 1, 10)
    s = 0.
    while relTimes[j] <= time
      s += relVal[j]
      j += 1
      if j > length(relTimes)
        break
      end
    end
    tRank[time] = s
  end
  return tRank 
end

XLSX.openxlsx(fname*"_ret_rel_t.xlsx", mode="w") do xf
  row = 2
  sheet = xf[1]
  XLSX.rename!(sheet, "cost_by_age")
  sheet["A1"] = "t"
  sheet["B1"] = [t for t in range(0.1, 1, 10)]
  for i in 0:I-1
    #: Existing
    lVals = [value(wRet[i, j]) for j in 1:N[i]-1]
    lRelAge = [j/(N[i]-1) for j in 1:N[i]-1]
    tRank = relTimeClass(lVals, lRelAge)
    sheet["A$(row)"] = "w_$(i)"
    sheet["B$(row)"] = [tRank[t] for t in range(0.1, 1, 10)]
    row += 1
  end
  # retrofits go into a separate sheet
  row = 2
  XLSX.addsheet!(xf)
  sheet = xf[2]
  XLSX.rename!(sheet, "cost_by_age_rf")
  sheet["A1"] = "t"
  sheet["B1"] = [t for t in range(0.1, 1, 10)]
  for i in 0:I-1
    #: RF
    for k in 0:Kz[i]-1
      lVals = [value(zRet[i, k, j]) for j in 1:Nz[i, k]-1]
      lRelAge = [j/(Nz[i, k]-1) for j in 1:Nz[i, k]-1]
      tRank = relTimeClass(lVals, lRelAge)
      sheet["A$(row)"] = "z_$(i)_$(k)"
      sheet["B$(row)"] = [tRank[t] for t in range(0.1, 1, 10)]
      row += 1
    end
  end
  row = 2
  XLSX.addsheet!(xf)
  sheet = xf[3]
  XLSX.rename!(sheet, "cost_by_age_new")
  sheet["A1"] = "t"
  sheet["B1"] = [t for t in range(0.1, 1, 10)]
  for i in 0:I-1
    #: New
    for k in 0:Kx[i]-1
      lVals = [value(xRet[i, k, j]) for j in 1:Nx[i,k]-1]
      lRelAge = [j/(Nx[i, k]-1) for j in 1:Nx[i, k]-1]
      tRank = relTimeClass(lVals, lRelAge)
      sheet["A$(row)"] = "x_$(i)_$(k)"
      sheet["B$(row)"] = [tRank[t] for t in range(0.1, 1, 10)]
      row += 1
    end
  end
 
end

XLSX.openxlsx(fname*"_ret_t_ucap.xlsx", mode="w") do xf
  row = 2
  sheet = xf[1]
  XLSX.rename!(sheet, "cap_by_age")
  sheet["A1"] = "t"
  sheet["B1"] = [t for t in range(0.1, 1, 10)]
  for i in 0:I-1
    #: Existing
    lVals = [sum(value(uw[t, i, j]) for t in 0:T-1) for j in 1:N[i]-1]
    lRelAge = [j/(N[i]-1) for j in 1:N[i]-1]
    tRank = relTimeClass(lVals, lRelAge)
    sheet["A$(row)"] = "w_$(i)"
    sheet["B$(row)"] = [tRank[t] for t in range(0.1, 1, 10)]
    row += 1
  end
  row = 2
  XLSX.addsheet!(xf)
  sheet = xf[2]
  XLSX.rename!(sheet, "cap_by_age_rf")
  sheet["A1"] = "t"
  sheet["B1"] = [t for t in range(0.1, 1, 10)]
  for i in 0:I-1
    #: RF
    for k in 0:Kz[i]-1
      lVals = [sum(value(uz[t, i, k, j]) for t in 0:T-1) for j in 1:Nz[i, k]-1]
      lRelAge = [j/(Nz[i, k]-1) for j in 1:Nz[i, k]-1]
      tRank = relTimeClass(lVals, lRelAge)
      sheet["A$(row)"] = "z_$(i)_$(k)"
      sheet["B$(row)"] = [tRank[t] for t in range(0.1, 1, 10)]
      row += 1
    end
  end
  row = 2
  XLSX.addsheet!(xf)
  sheet = xf[3]
  XLSX.rename!(sheet, "cap_by_age_new")
  sheet["A1"] = "t"
  sheet["B1"] = [t for t in range(0.1, 1, 10)]
  for i in 0:I-1
    #: New
    for k in 0:Kx[i]-1
      lVals = [sum(value(ux[t, i, k, j]) for t in 0:T-1) for j in 1:Nx[i, k]-1]
      lRelAge = [j/(Nx[i, k]-1) for j in 1:Nx[i, k]-1]
      tRank = relTimeClass(lVals, lRelAge)
      sheet["A$(row)"] = "x_$(i)_$(k)"
      sheet["B$(row)"] = [tRank[t] for t in range(0.1, 1, 10)]
      row += 1
    end
  end
end




XLSX.openxlsx(fname*"_ret_rel.xlsx", mode="w") do xf
  row = 2
  sheet = xf[1]
  XLSX.rename!(sheet, "cost_by_age")
  sheet["A1"] = "time"
  max_age = [maximum(values(N)), maximum(values(Nz)), maximum(values(Nx))]
  max_age = maximum(max_age)
  max_age = max_age
  sheet["B1"] = [j for j in 1:max_age-1]
  for i in 0:I-1
    #: Existing
    sheet["A$(row)"] = "t"
    sheet["B$(row)"] = [j/(N[i]-1) for j in 1:N[i]-1]
    sheet["A$(row+1)"] = "w_$(i)"
    sheet["B$(row+1)"] = [value(wRet[i, j]) for j in 1:N[i]-1]
    row += 2
    #: RF
    for k in 0:Kz[i]-1
      sheet["A$(row)"] = "t"
      sheet["B$(row)"] = [j/(Nz[i, k]-1) for j in 1:Nz[i, k]-1]
      sheet["A$(row+1)"] = "z_$(i)_$(k)"
      sheet["B$(row+1)"] = [value(zRet[i, k, j]) for j in 1:Nz[i, k]-1]
      row += 2
    end
    #: New
    for k in 0:Kx[i]-1
      sheet["A$(row)"] = "t"
      sheet["B$(row)"] = [j/(Nx[i, k]-1) for j in 1:Nx[i, k]-1]
      sheet["A$(row+1)"] = "x_$(i)_$(k)"
      sheet["B$(row+1)"] = [value(xRet[i, k, j]) for j in 1:Nx[i,k]-1]
      row += 2
    end
  end
end

XLSX.openxlsx(fname*"_zx_cap.xlsx", mode="w") do xf
  row = 2
  sheet = xf[1]
  XLSX.rename!(sheet, "cost_rf")
  sheet["A1"] = "tech"
  for i in 0:I-1
    #: RF
    for k in 0:Kz[i]-1
      sheet["A$(row)"] = "z_$(i)_$(k)"
      sheet["B$(row)"] = sum(value(zOcap[t, i, k]) for t in 0:T-1)
      row += 1
    end
  end
  ####
  XLSX.addsheet!(xf)
  row = 2
  sheet = xf[2]
  XLSX.rename!(sheet, "cost_new")
  sheet["A1"] = "tech"
  for i in 0:I-1
    #: New
    for k in 0:Kx[i]-1
      sheet["A$(row)"] = "x_$(i)_$(k)"
      sheet["B$(row)"] = sum(value(xOcap[t, i]) for t in 0:T-1) 
      row += 1
    end
  end

  XLSX.addsheet!(xf)
  sheet = xf[3]
  row = 2
  XLSX.rename!(sheet, "rf_cap")
  sheet["A1"] = "tech"
  for i in 0:I-1
    #: Existing
    #: RF
    for k in 0:Kz[i]-1
      sheet["A$(row)"] = "z_$(i)_$(k)"
      # N[i] because we only consider the years of existing cap
      sheet["B$(row)"] = sum(value(zp[t, i, k, j]) for t in 0:T-1 for j in 1:N[i]-1) 
      row += 1
    end
  end
  XLSX.addsheet!(xf)
  sheet = xf[4]
  row = 2
  XLSX.rename!(sheet, "new_cap")
  sheet["A1"] = "tech"
  for i in 0:I-1
    #: New
    for k in 0:Kx[i]-1
      sheet["A$(row)"] = "x_$(i)_$(k)"
      sheet["B$(row)"] = sum(value(x[t, i, k, 0]) for t in 0:T-1) 
      row += 1
    end
  end
end



@info("Done for good.\n")
@info("Out files:\t$(fname0)\n")


#variables of interest

