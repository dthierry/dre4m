import Clp
Clp.Clp_Version()

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

kinds_z = [1, # 0
           0, # 1
           1, # 2
           0, # 3
           0, # 4
           0, # 5
           0, # 6
           0, # 7
           0, # 8
           0, # 9
           0, # 10
          ]
# Set cardinality
# Subprocess
I = 11


# Time horizon
T = 50

# Age - 1, 2, 3, ....
# We can have parameters as function of the year, age

# Read excel file
sheet = "Nom"  # Source sheet
XLSX.openxlsx(inputExcel, mode="r", enable_cache=true) do xf
  s = xf["Nom"]
  # Capacities (MWh, f(age))
  global cap_mat = s["B3:BJ13"]
  # Age of the plant :?
  global dis_mat = s["B17:BJ27"]
  # Fuel price ($/MMBTU)
  global fuel_mat = s["B31:CS41"]
  # Capital cost ($/kW, f(time))
  global cc_mat = s["B45:CS55"]
  # Fixed O&M costs ($/kW-yr, f(age))
  global foam_mat = s["B59:CS69"]
  # Variable O&M costs ($/MWh, f(age))
  global voam_mat = s["B73:CS83"]
  # Capacity factor \in [0,1]
  global cfac_mat = s["B101:CS111"]
  # OLD Heat rate (BTU/kWh, f(age))
  global heatRateInputMatrix = s["B157:BI167"]
  # heat rate for 6 ... is 0
  # NEW Heat rate (BTU/kWh, f(year))
  global heatRateInputMatrixNew = s["B87:CS97"]
  # hear rate for 6, 7, 8, 9, 10 is 0
  # LCCA $/MWh 
  global util_techcost = s["B115:CS125"]
  # Cent/MWh
  global util_revenues = s["B143:CS153"]
  # $/MWh
  global util_decom = s["B171:BI181"]
  # Demand (MWh, f(year))
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

# (MWh) --> (GWh)
cap_mat = cap_mat./1e3

# ($/MMBTU) --> (M$/MMBTU)
fuel_mat = fuel_mat./1e6 # M$/MMBTU

# (BTU/kWh) --> (MMBTU/GWh) Same thing!
# heatRateInputMatrix = heatRateInputMatrix # to (MMBTU/GWh)
# (BTU/kWh) --> (MMBTU/GWh) Same thing!
# heatRateInputMatrixNew = heatRateInputMatrixNew # to (MMBTU/GWh)

# ($/MWh) --> (M$/GWh)
util_techcost = util_techcost.*(1e3/1e6)
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
foam_mat = foam_mat./(24*365)

# ($/MWh) --> (M$/GWh)
voam_mat = voam_mat.*(1e3/1e6) 

# ($/kW) --> (M$/GW) Same thing!
# kWh = kW * hours 
# cc_mat = cc_mat 

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
  Kz[i] = kinds_z[i + 1]
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
N_k = Dict()
for i in 0:I-1
  for k in 0:Kx[i]-1
    N_k[(i, k)] = discard[i] # assume the same, simple as
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
wOandMgwh = Dict()
for i in 0:I-1
  for t in 0:T-1
    wOandMgwh[t, i] = (foam_mat[i+1, t+1]/(cfac_mat[i+1, t+1]) + voam_mat[i+1, t+1])/((1+discountRate)^t)
  end
end

# factor for fixed
retroCfOandM = Dict(0 => 2.130108424, #pc
                1 => 1.17001519, # igcc
                2 => 2.069083447)

for i in 3:I-1
retroCfOandM[i] = 0.0
end
# factor for variable 
retroCvOandM = Dict(0 => 2.129411764, #pc
                1 => 1.170305679, # igcc
                2 => 2.07395498)

for i in 3:I-1
retroCvOandM[i] = 0.0
end


# (retrofit)
zOandMgwh = Dict()
for i in 0:I-1
  for k in 0:Kz[i]-1
    for t in 0:T-1
      zOandMgwh[t, i, k] = (
                            retroCfOandM[i] * foam_mat[i+1, t+1]/(cfac_mat[i+1, t+1])
                            + retroCvOandM[i] * voam_mat[i+1, t+1])/((1+discountRate)^t)
    end
  end
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


# Overnight, this should be only for new capacity
xCapCostGwh = Dict()
for i in 0:I-1
  for t in 0:T-1
    xCapCostGwh[t, i] = ((cc_mat[i+1, t+1])/(365*24*cfac_mat[i+1, t+1]))/((1+discountRate)^t)
  end
end

# factor for retrofit
retroCc = Dict(0 => 0.625693161, #pc
                1 => 0.499772727, # igcc
                2 => 1.047898338)

for i in 3:I-1
retroCc[i] = 0.0
end

# retrofit overnight capital cost
zCapCostGwh = Dict()
for i in 0:I-1
  for k in 0:Kz[i]-1
    for t in 0:T-1
      zCapCostGwh[t, i, k] = retroCc[i] * xCapCostGwh[t, i]
    end
  end
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
    sheet["B"*string(t+2)] = [xCapCostGwh[t, i] for i in 0:I-1]
  end
end
currSheet += 1


t0=Dict()
t1=Dict()
t2=Dict()
#%
retireCost = Dict()
for t in 0:T-1
  for i in 0:I-1
    for j in 0:N[i]-1
      baseAge = t - j > 0 ? t - j : 0
      #retireCost[t, i, j] = 
      # loan liability
      #(max(loan_period - j, 0)/loan_period) * util_techcost[i+1, baseAge+1]/((1+discountRate)^t)
      #
      # lost revenue (number of years remaining * rev/yr)
      #+ (max(serviceLife[i+1] - j, 0)
      #   *util_revenues[i+1,t+1]/cfac_mat[i+1, t+1])/((1+discountRate)^t) 
      # decommission
      #+ util_decom[i+1, j+1]
      t0[t, i, j]=(max(loan_period - j, 0)/loan_period) * util_techcost[i+1, baseAge+1]/((1+discountRate)^t)
      t1[t, i, j]=(max(serviceLife[i+1] - j, 0)*util_revenues[i+1,t+1]/cfac_mat[i+1, t+1])/((1+discountRate)^t)
      t2[t, i, j]=util_decom[i+1, j+1]/((1+discountRate)^t)
      retireCost[t, i, j] = t0[t,i,j] + t1[t,i,j] + t2[t,i,j]
    end
  end
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

xDelay = Dict([i => 3 for i in 0:I-1])
xDelay[techToId["PC"]] = 6
xDelay[techToId["NGCT"]] = 4
xDelay[techToId["NGCC"]] = 4
xDelay[techToId["N"]] = 10
xDelay[techToId["H"]] = 10

maxDelay = maximum(values(xDelay))

# new asset
@variable(m, x[t = -maxDelay:T, i = 0:I-1, 
               k = 0:Kx[i]-1, j = 0:N_k[(i, k)]] >= 0)
#: made a ficticious point N_k so we can know how much is retired because it
#: becomes too old

# retired new asset
@variable(m, ux[t = -maxDelay:T, i = 0:I-1, 
                k = 0:Kx[i]-1, j = 1:N_k[(i, k)]-1] >= 0)
# can't retire at j = 0

# retrofitted asset
@variable(m, 
          z[t=0:T, i=0:I-1, k=0:Kz[i]-1, j=0:Nz[i, k]] >= 0)
#: no retrofits at age 0

#: the retrofit can't happen at the end of life of a plant, i.e., j goes from
#: 0 to N[i]-12
#: the retrofit can't happen at the beginning of life of a plant, i.e. j = 0
#: made a ficticious point N_kj so we can know how much is retired because it
#: becomes too old

@variable(m,
          zp[t = 0:T, i = 0:I-1, k = 0:Kz[i]-1, j = 1:N[i]-1] >= 0)
#: zp only goes as far as the base age N

# retired retrofit
@variable(m, 
          uz[t = 0:T, i = 0:I-1, k = 0:Kz[i]-1, j = 1:(Nz[i, k]-1)] >= 0)
# can't retire at the first year of retrofit, jk = 0
# can't retire at the last year of retrofit, i.e. jk = |N_kj| 
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
                 j = 2:N_k[(i, k)]],
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
#            z_end_E[t=1:T, i=0:I-1, k=0:Kz[i]-1, jk=0:N_kj[(i, k, N[i]-1)]-1],
#            z[t, i, k, N[i]-1, jk] == 0
#           )

# initial condition new plants of new tech
@constraint(m,
          initial_x[i=0:I-1, k=0:Kx[i]-1, j=0:N_k[(i, k)]-1],
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
            j=0:N_k[i, k]-1] 
          )


@constraint(m, X_E0[t=0:T-1, i=0:I-1, k=0:Kx[i]-1],
            X[t, i, k, 0] == #effCapInd_x[i, k, 0] * 
            x[t-xDelay[i], i, k, 0]
           )
#: oi!, leading time needed here
#
@constraint(m, X_E[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, j=1:N_k[i, k]-1],
            X[t, i, k, j] == #effCapInd_x[i, k, j] * 
            (x[t, i, k, j] - ux[t, i, k, j])
           )
#: these are the hard questions

# Demand (GWh)
d = Dict()
for t in 0:T-1
  d[(t, 0)] = d_mat[t+1]
end


# Delivery capacity
#@variable(m, slk[t=1:4] >= 0)
#=
# Demand Slack
@constraint(m,
            dUnmetE[t = 1:4],
            sum(
            # old
            sum(W[t, i, j] for j in 1:N[i]-1)
            # retrofit
            + sum(sum(sum(Z[t, i, k, j, jk] 
                    for jk in 0:N_kj[(i, k, j)]-1) for j in 1:N[i]-1)
                for k in 0:Kz[i]-1) 
            # new
            + sum(sum(X[t, i, k, j] for j in 0:N_k[i, k]-1) 
                  for k in 0:Kx[i]-1) for i in 0:I-1)
            == d[(t, 0)] - slk[t]
           )
=#
#for t in 20:T-1
#  d[(t, 0)] = d[(19, 0)] * (1+ 0.5*(-1 + 2*(floor(Int, t/10) % 2)))
#end



# Demand
@constraint(m,
            dcCon[t = 10:T-1],
            sum(
            # old
            sum(W[t, i, j] for j in 0:N[i]-1)
            # retrofit
            + sum(sum(Z[t, i, k, j] for j in 1:(Nz[i,k]-1))
                      for k in 0:Kz[i]-1)
            # new
            + sum(sum(X[t, i, k, j] for j in 0:N_k[i, k]-1) 
                  for k in 0:Kx[i]-1) 
            for i in 0:I-1)
            >= d[(t, 0)]
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
#            + sum(sum(X[t, i, k, j] for j in 0:N_k[i, k]-1) 
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
      #for j in 0:N_k[id, k]
      set_upper_bound(x[t, id, k, 0], upperBoundDict[tech])
      #end
    end
  end
end


# ubUtilmod(squish(6,k,1,N_Util,Tcrit_Util)) = 1000*365*24*0.898;   
# % limit new nuclear to no more than 1000 MW a year
# ubUtilmod(squish(7,k,1,N_Util,Tcrit_Util)) = 1000*365*24*0.42;   
# % limit new hydro to increase at no more than 1000 MW a year

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
  global s = 0
  for i in 0:I-1
    for k in 0:Kz[i]-1
      global s += 1
      XLSX.addsheet!(xf)
      sheet = xf[s]
      XLSX.rename!(sheet, "heatRate-$(i)-MMBTUperGWh")
      sheet["A1"] = "time"
      sheet["A2", dim=1] = collect(0:T-1)
      sheet["B1"] = ["age=$(j)" for j in 0:Nz[i, k]-1]
      for t in 0:T-1
        sheet["B"*string(t+2)] = [heatRateWf(i, j, t, N[i]-1) for j in 0:Nz[i, k]-1]
      end
    end
  end
end

function heatRateXf(baseKind, kind, age, time)
  if time < age
    return 0
  end
  baseTime = time - age # simple as.
  baseTime = max(baseTime - xDelay[baseKind], 0) # but actually if it's less than 0 just take 0
  return heatRateInputMatrixNew[baseKind+1, baseTime+1] * (1 + heatIncreaseRate) ^ time
end

XLSX.openxlsx(fname*"_heatRateX.xlsx", mode="w") do xf
  global s = 0
  for i in 0:I-1
    for k in 0:Kx[i]-1
      global s += 1
      XLSX.addsheet!(xf)
      sheet = xf[s]
      XLSX.rename!(sheet, "heatRate-$(i)-MMBTUperGWh")
      sheet["A1"] = "time"
      sheet["A2", dim=1] = collect(0:T-1)
      sheet["B1"] = ["age=$(j)" for j in 0:N_k[i, k]-1]
      for t in 0:T-1
        sheet["B"*string(t+2)] = [heatRateXf(i, k, j, t) for j in 0:N_k[i, k]-1]
      end
    end
  end
end

heatRateNew = Dict()
for t in 0:T
  for i in 0:I-1
    for k in 0:Kx[i]-1
      for jk in 0:N_k[i, k]-1
          heatRateNew[t, i, jk] = heatRateInputMatrixNew[i+1, t+1] * (1 + heatIncreaseRate)^jk
      end
    end
  end
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
          heat_x[t=-maxDelay:T-1, i=0:I-1, 
                 k=0:Kx[i]-1, 
                 j=0:N_k[i, k]-1; fuelBased[i]])


@constraint(m,
            heat_w_E[t=0:T-1, i=0:I-1, 
                     j=0:N[i]-1; fuelBased[i]],
            heat_w[t, i, j] == 
            W[t, i, j] * heatRateWf(i, j, t, N[i]-1)
           )


@constraint(m,
            heat_z_E[t = 0:T-1, i = 0:I-1, k = 0:Kz[i]-1, 
                     j = 0:Nz[i, k]-1; fuelBased[i]],
            heat_z[t, i, k, j] == 
            Z[t, i, k, j] * heatRateWf(i, j, t, N[i]-1) * 1.34
           )

@constraint(m,
            heat_x_E[t=-maxDelay:T-1, i=0:I-1, k=0:Kx[i]-1, 
                     j=0:N_k[i, k]-1; fuelBased[i]],
            heat_x[t, i, k, j] == 
            X[t, i, k, j] * heatRateXf(i, k, j, min(0, t)) 
           )

# Carbon emission (tCO2)
@variable(m, 
          wE[t = 0:T-1, i = 0:I-1, j = 0:N[i]-1; co2Based[i]])

@variable(m, 
          zE[t=0:T-1, i=0:I-1, k=0:Kz[i]-1, j=0:Nz[i, k]-1; co2Based[i]])

@variable(m, 
          xE[t=-maxDelay:T-1, i=0:I-1, k=0:Kx[i]-1, j=0:N_k[i, k]-1; co2Based[i]])


@constraint(m,
            e_wCon[t=0:T-1, i=0:I-1, 
                   j=0:N[i]-1; co2Based[i]],
            wE[t, i, j] == heat_w[t, i, j] * emissionRate[i+1]
           )

@constraint(m,
            e_zCon[t = 0:T-1, i = 0:I-1, k =0:Kz[i]-1, 
                   j=0:Nz[i, k]-1; co2Based[i]],
            zE[t, i, k, j] == 
            heat_z[t, i, k, j] * emissionRate[i+1] * 0.15
           )

@constraint(m,
 e_xCon[t=-maxDelay:T-1, i=0:I-1, k=0:Kx[i]-1, 
        j=0:N_k[i, k]-1; co2Based[i]],
 xE[t, i, k, j] == heat_x[t, i, k, j] * emissionRate[i+1]
)

# (overnight) Capital for new capacity
@variable(m, xOcap[t=-maxDelay:T-1, i=0:I-1])
@constraint(m, xOcapE[t=-maxDelay:T-1, i=0:I-1],
            xOcap[t, i] == sum(
                               xCapCostGwh[min(t, i)] * x[t, i, k, 0]
                               for k in 0:Kx[i]-1
                              )
           )
#: You'd need to add an additional index if you have an upgraded new capacity.

# (overnight) Capital for retrofits

@variable(m, zOcap[t=0:T-1, i=0:I-1])
@constraint(m, zOcapE[t=0:T-1, i=0:I-1],
            zOcap[t, i] == sum(
                               zCapCostGwh[t, i, k] * zp[t, i, k, j]
                               for k in 0:Kz[i]-1
                               for j in 1:N[i]-1 #: only related to the base age
                              )
           )


# Operation and Maintenance for existing 
@variable(m,
          wOAndM[t=0:T-1, i=0:I-1])
#: I think you don't need bounds if the coefficients below are positive.
@constraint(m,
            wOAndM_E[t=0:T-1, i=0:I-1],
            wOAndM[t, i] == 
            wOandMgwh[t, i] * sum(W[t, i, j]
                              for j in 0:N[i]-1)
           )

# O and M for retrofit
@variable(m,
          zOandM[t=0:T-1, i=0:I-1])
@constraint(m,
            zOandM_E[t=0:T-1, i=0:I-1],
            zOandM[t, i] == 
            sum(zOandMgwh[t, i, k] * Z[t, i, k, j] 
                  for k in 0:Kz[i]-1 
                  for j in 0:N[i]-1 #: only related to the base age
                  ))

# O and M for new
@variable(m,
          xOandM[t=-maxDelay:T-1, i=0:I-1])

@constraint(m,
            xOandM_E[t=-maxDelay:T-1, i=0:I-1],
            xOandM[t, i] == 
            sum(xOandMgwh[min(t, 0), i, k] * X[t, i, k, j] 
                for k in 0:Kx[i]-1 
                for j in 0:N_k[i, k]-1)
           )


# Fuel
@variable(m, wFuelC[t=0:T-1, i=0:I-1; fuelBased[i]])

@variable(m, zFuelC[t=0:T-1, i=0:I-1; fuelBased[i]])

@variable(m, xFuelC[t=-maxDelay:T-1, i=0:I-1; fuelBased[i]])
#: fuel costs only include those techs that are based in fuel burning

function fuelDiscounted(kind, time)
  return fuel_mat[kind+1, time+1] / ((1+discountRate)^time)
end

@constraint(m, wFuelC_E[t=0:T-1, i=0:I-1; fuelBased[i]],
            wFuelC[t, i] == 
            fuelDiscounted(i, t) * sum(heat_w[t, i, j]
                              for j in 0:N[i]-1) 
           )

@constraint(m, zFuelC_E[t=0:T-1, i=0:I-1; fuelBased[i]],
            zFuelC[t, i] == 
            fuelDiscounted(i, t) * sum(heat_z[t, i, k, j] 
                                              for k in 0:Kz[i]-1
                                              for j in 0:Nz[i, k]-1
                                              )
           )

@constraint(m, xFuelC_E[t=-maxDelay:T-1, i=0:I-1; fuelBased[i]],
            xFuelC[t, i] == 
            fuelDiscounted(i, min(t, 0)) * sum(heat_x[t, i, k, j] 
                                              for k in 0:Kx[i]-1
                                              for j in 0:N_k[i, k]-1
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
                 for j in 0:N_k[i, k]-1 if co2Based[i])
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
@variable(m, xOldRet[t=-maxDelay:T-1, i=0:I-1, k=0:Kx[i]-1])

@constraint(m, wOldRetE[t=1:T-1, i=0:I-1],
            wOldRet[t, i] == 
            retireCost[t, i, N[i]-1] * w[t, i, N[i]]
           )

@constraint(m, zOldRetE[t=1:T-1, i=0:I-1, k=0:Kz[i]-1],
            zOldRet[t, i, k] == 
            retireCost[t, i, N[i]-1] * z[t, i, k, Nz[i, k]]
           )


@constraint(m, xOldRetE[t=-maxDelay:T-1, i=0:I-1, k=0:Kx[i]-1],
            xOldRet[t, i, k] == 
            retireCost[min(t, 0), i, N_k[i, k]-1] * x[t, i, k, N_k[i, k]]
           )

# "Forced" retirement
@variable(m, wRet)
@variable(m, zRet)
@variable(m, xRet)

@constraint(m, wRet_E,
            wRet == sum(uw[t, i, j] * retireCost[t, i, j]
                        for t in 0:T-1 
                        for i in 0:I-1 
                        for j in 1:N[i]-1)
           )

@constraint(m, zRet_E,
            zRet == sum(uz[t, i, k, j] * retireCost[t, i, min(j, N[i]-1)] 
                        for t in 0:T-1
               for i in 0:I-1 
               for k in 0:Kz[i]-1 
               for j in 1:Nz[i, k]-1 
              ))


@constraint(m, xRet_E,
            xRet == sum(ux[t, i, k, j] * retireCost[t, i, j] 
                        for t in -maxDelay:T-1 
                        for i in 0:I-1 
                        for k in 0:Kx[i]-1 
                        for j in 1:N_k[i, k]-1)
           )

# Net present value
@variable(m, npv)
@constraint(m, npv_e, 
            npv == 
            # overnight
            sum(
                zOcap[t, i]
                + xOcap[t, i]
                for t in 0:T-1
                for i in 0:I-1
               )
            # op and maint
            + sum(
                 wOAndM[t, i] 
                 + zOandM[t, i] 
                 + xOandM[t, i] 
                 for t in 0:T-1 
                 for i in 0:I-1)
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
            + wRet 
            + zRet 
            + xRet 
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
                       j=0:N_k[i,k]-1],
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
                  for j in 0:N_k[i, k]-1)
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
      sheet["C1"] = ["newAge=$(j)" for j in 0:N_k[i,k]-1]
      sheet["A2", dim=1] = collect(0:T)
      # sheet["B2", dim=1] = [1 for i in 0:T]
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(x[t, i, k, j]) for j in 0:N_k[i,k]-1]
      end

      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "ux_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      # sheet["B1"] = "i = PC"
      sheet["C1"] = ["eNwAge=$(j)" for j in 1:N_k[i,k]-1]
      sheet["A2", dim=1] = collect(0:T)
      # sheet["B2", dim=1] = [1 for i in 0:T]
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(ux[t, i, k, j]) for j in 1:N_k[i,k]-1]
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
    sheet["B1"] = ["newAge=$(j)" for j in 0:N_k[i,k]-1]
    sheet["A2", dim=1] = collect(0:T)
    for t in 0:T-1
      ts = string(t + 2)
      sheet["B"*ts] = [value(xE[t, i, k, j]) for j in 0:N_k[i,k]-1]
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
      sheet["C1"] = ["newAge=$(j)" for j in 0:N_k[i,k]-1]
      sheet["A2", dim=1] = collect(0:T)
      # sheet["B2", dim=1] = [1 for i in 0:T]
      for t in 0:T-1
        ts = string(t + 2)
        sheet["C"*ts] = [value(X[t, i, k, j]) for j in 0:N_k[i,k]-1]
      end

      global sh += 1
      XLSX.addsheet!(xf)
      sheet = xf[sh]
      XLSX.rename!(sheet, "ux_"*string(i)*"_"*string(k))
      sheet["A1"] = "time"
      # sheet["B1"] = "i = PC"
      sheet["C1"] = ["eNwAge=$(j)" for j in 1:N_k[i,k]-1]
      sheet["A2", dim=1] = collect(0:T)
      # sheet["B2", dim=1] = [1 for i in 0:T]
      for t in 0:T
        ts = string(t + 2)
        sheet["C"*ts] = [value(ux[t, i, k, j]) for j in 1:N_k[i,k]-1]
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
  sheet["B4"] = value(wRet) + value(zRet) + value(xRet) 
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


@info("Done for good.\n")
@info("Out files:\t$(fname0)\n")


#variables of interest

