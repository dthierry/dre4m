# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################

using JuMP
import Dates

"""
    genModel(mS::modSets, modData::modData)::JuMP.Model
Generates model with variables and constraints.
"""
function genModel(mS::modSets, mD::modData)::JuMP.Model
  #: Initial sets
  T = mS.T
  I = mS.I
  N = mS.N
  Nz = mS.Nz
  Nx = mS.Nx
  Kz = mS.Kx
  Kx = mS.Kx
  modData.ta
  #: Model creation
  m = Model()
  #  open(fname*"_kinds.txt", "w") do file
  #    write(file, "kinds_z\n")
  #    for i in 0:I-1
  #      write(file, "$(kinds_z[i+1])\n")
  #    end
  #    write(file, "kinds_x\n")
  #    for i in 0:I-1
  #      write(file, "$(kinds_x[i+1])\n")
  #    end
  #  end
  ##
  #@info("The budget: $((co22010 + co22050) * 0.5 * 41 - co2_2010_2015)")
  #: Last term is a trapezoid minus the 2010-2015 gap

  # Variables
  # this goes to N just because we need to constrain z at N-1
  # existing asset (GWh)
  @variable(m,
            w[t=0:T, i=0:I-1, j=0:N[i]] >= 0.)
  
  # retired existing asset
  @variable(m, uw[t = 0:T, i = 0:I-1, j = 1:N[i]-1] >= 0)
  # we don't retire at year 0 or at the last year i.e \{0, N}
  #
  
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

  # Effective capacity old
  @variable(m, W[t=0:T-1, 
                 i=0:I-1, 
                 j=0:N[i]-1])

  @variable(m, 
            Z[t=0:T-1, i=0:I-1, k=0:Kz[i]-1, j=0:(Nz[i, k]-1)]
           )
  # Effective capacity new
  @variable(m,
            X[t=0:T-1, i=0:I-1, 
              k=0:Kx[i]-1, 
              j=0:Nx[i, k]-1] 
            )

  #: hey let's just create effective generation variables instead
  #: it seems that the capacity factors are the same regardless of 
  #: us having retrofits, new capacity, etc.
  yrHr = 24 * 365  # hours in a year

  @variable(m, 
            Wgen[t=0:T-1, i=0:I-1, j=0:N[i]-1])

  @variable(m, 
            Zgen[t=0:T-1, i=0:I-1, k=0:Kz[i]-1, j=0:(Nz[i, k]-1)])

  @variable(m, 
            Xgen[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, j=0:(Nx[i, k]-1)])

  #: Generation (GWh)
  @variable(m, sGen[t = 1:T-1, i = 0:I-1]) #: supply generated

  @variable(m, heat_w[t = 0:T-1, i = 0:I-1, j = 0:N[i]-1; fuelBased[i]])

  @variable(m, 
            heat_z[t=0:T-1, 
                   i=0:I-1, k=0:Kz[i]-1, j=0:Nz[i, k]-1; fuelBased[i]])

  @variable(m, 
            heat_x[t=0:T-1, i=0:I-1, 
                   k=0:Kx[i]-1, 
                   j=0:Nx[i, k]-1; fuelBased[i]])
  # Carbon emission (tCO2)
  @variable(m, 
            wE[t = 0:T-1, i = 0:I-1, j = 0:N[i]-1; co2Based[i]])

  @variable(m, 
            zE[t=0:T-1, i=0:I-1, k=0:Kz[i]-1, j=0:Nz[i, k]-1; co2Based[i]])

  @variable(m, 
            xE[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, j=0:Nx[i, k]-1; co2Based[i]])


  # (overnight) Capital for new capacity
  @variable(m, xOcap[t=0:T-1, i=0:I-1])

  # (overnight) Capital for retrofits
  @variable(m, zOcap[t=0:T-1, i=0:I-1, k=0:Kz[i]-1])
  # Operation and Maintenance for existing 
  #: Do we have to partition this term?
  @variable(m, wFixOnM[t=0:T-1, i=0:I-1])
  @variable(m, wVarOnM[t=0:T-1, i=0:I-1])
 
  # O and M for retrofit
  @variable(m, zFixOnM[t=0:T-1, i=0:I-1])
  @variable(m, zVarOnM[t=0:T-1, i=0:I-1])
  # O and M for new
  @variable(m, xFixOnM[t=0:T-1, i=0:I-1])
  @variable(m, xVarOnM[t=0:T-1, i=0:I-1])
  # Fuel
  @variable(m, wFuelC[t=0:T-1, i=0:I-1; fuelBased[i]])

  @variable(m, zFuelC[t=0:T-1, i=0:I-1; fuelBased[i]])

  @variable(m, xFuelC[t=0:T-1, i=0:I-1; fuelBased[i]])

  @variable(m, 
            co2OverallYr[t=0:T-1]
            #1.49E+11 * 0.7
           )
  # <= 6.71E+10 * 0.7)
  # <=6.71E+10 * 0.7)

  # Natural "organic" retirement
  @variable(m, wOldRet[t=1:T-1, i=0:I-1])
  @variable(m, zOldRet[t=1:T-1, i=0:I-1, k=0:Kz[i]-1])
  @variable(m, xOldRet[t=1:T-1, i=0:I-1, k=0:Kx[i]-1])

  # "Forced" retirement
  @variable(m, wRet[i=0:I-1, j=1:N[i]-1])
  @variable(m, zRet[i=0:I-1, k=0:Kz[i]-1, j=1:Nz[(i, k)]-1])
  @variable(m, xRet[i=0:I-1, k=0:Kx[i]-1, j=1:Nx[(i, k)]-1])

  # Net present value
  @variable(m, npv) # ≥ 1000. * 2000.)
  # Terminal cost
  @variable(m, termCw[i=0:I-1, j=0:N[i]-1])

  @variable(m, termCx[i=0:I-1,
                      k=0:Kx[i],
                      j=0:N[i]-1])

  @variable(m, termCz[i=0:I-1, k=0:Kz[i]-1, 
                      j=0:Nz[i, k]-1])

  @variable(m, termCost >= 0)
  
  ############ Constraint definition $$$$$$$$$$$$

  # w0 balance0
  @constraint(m, 
            wbal0[t = 0:T-1, i = 0:I-1],
            w[t+1, i, 1] == w[t, i, 0])
  # can't retire stuff at the beginning, can't retrofit stuff as well
  
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
  # x balance
  @constraint(m,
              xbal[t = 0:T-1, i = 0:I-1, k = 0:Kx[i]-1, 
                   j = 2:Nx[(i, k)]],
                   x[t+1, i, k, j] == x[t, i, k, j-1] - ux[t, i, k, j-1]
                  )
  # don't allow new assets to be retired at 0
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

  # Equations
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
  @constraint(m, WgEq[t=0:T-1, i=0:I-1, j=0:N[i]-1], 
              Wgen[t, i, j] == YrHr * cFactW[t, i, j]  * W[t, i, j]
              )
  @constraint(m, ZgEq[t=0:T-1, i=0:I-1, k=0:Kz[i]-1, j=0:Nz[i, k]-1],
              Zgen[t, i, k, j] == YrHr * cFactZ[t, i, k, j] * Z[t, i, k, j]
              )
  @constraint(m, XgEq[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, j=0:Nx[i, k]-1],
              Xgen[t, i, k, j] == YrHr * cFactX[t, i, k, j] * X[t, i, k, j]
              )
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

  # Trade in the values for actual generation. 
  @constraint(m,
              heat_w_E[t=0:T-1, i=0:I-1, 
                       j=0:N[i]-1; fuelBased[i]],
              heat_w[t, i, j] == 
              Wgen[t, i, j] * heatRateW(mD, i, j, t, N[i]-1)
             )


  @constraint(m,
              heat_z_E[t = 0:T-1, i = 0:I-1, k = 0:Kz[i]-1, 
                       j = 0:Nz[i, k]-1; fuelBased[i]],
              heat_z[t, i, k, j] == 
              Zgen[t, i, k, j] * heatRateZ(mD, i, k, j, t, N[i]-1)
             )

  @constraint(m,
              heat_x_E[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, 
                       j=0:Nx[i, k]-1; fuelBased[i]],
              heat_x[t, i, k, j] == 
              Xgen[t, i, k, j] * heatRateX(mD, i, k, j, t, N[i]-1) 
             )

  @constraint(m,
              e_wCon[t=0:T-1, i=0:I-1, 
                     j=0:N[i]-1; co2Based[i]],
              wE[t, i, j] == heat_w[t, i, j] * carbonIntW(mD, i)
             )

  @constraint(m,
              e_zCon[t = 0:T-1, i = 0:I-1, k =0:Kz[i]-1, 
                     j=0:Nz[i, k]-1; co2Based[i]],
              zE[t, i, k, j] == 
              heat_z[t, i, k, j] * carbonIntZ(mD, i, k)
             )

  @constraint(m,
              e_xCon[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, 
                     j=0:Nx[i, k]-1; co2Based[i]],
              xE[t, i, k, j] == heat_x[t, i, k, j] * carbonIntW(mD, i)
  )


  @constraint(m, xOcapE[t=0:T-1, i=0:I-1],
              xOcap[t, i] == sum(
                                 xCapCost(mD, i, t) * x[t, i, k, 0]
                                 for k in 0:Kx[i]-1
                                )
             )
  @constraint(m, zOcapE[t=0:T-1, i=0:I-1, k=0:Kz[i]-1],
              zOcap[t, i, k] == sum(
                                 zCapCost(mD, i, k, t) * zp[t, i, k, j]
                                 for j in 1:N[i]-1 
                                 #: only related to the base age
                                )
             )

  @constraint(m,
              wFixOnM_E[t=0:T-1, i=0:I-1],
              wFixOnM[t, i] == 
              wFixCost(mD, i, t) * sum(W[t, i, j] for j in 0:N[i]-1)
             )

  @constraint(m,
              wVarOnM_E[t=0:T-1, i=0:I-1],
              wVarOnM[t, i] == 
              wVarCost(mD, i, t) * sum(Wgen[t, i, j] for j in 0:N[i]-1)
             )

  @constraint(m,
              zFixOnM_E[t=0:T-1, i=0:I-1],
              zFixOnM[t, i] == 
              sum(zFixCost(mD, i, k, t) * Z[t, i, k, j] 
                    for k in 0:Kz[i]-1 
                    for j in 0:N[i]-1 #: only related to the base age
                    ))

  @constraint(m,
              zVarOnM_E[t=0:T-1, i=0:I-1],
              zVarOnM[t, i] == 
              sum(zVarCost(mD, i, k, t) * Zgen[t, i, k, j] 
                    for k in 0:Kz[i]-1 
                    for j in 0:N[i]-1 #: only related to the base age
                    ))


  @constraint(m,
              xFixOnM_E[t=0:T-1, i=0:I-1],
              xFixOnM[t, i] == 
              sum(wFixCost(mD, i, t) * X[t, i, k, j] 
                  for k in 0:Kx[i]-1 
                  for j in 0:Nx[i, k]-1)
             )

  @constraint(m,
              xVarOndM_E[t=0:T-1, i=0:I-1],
              xVarOnM[t, i] == 
              sum(wVarCost(mD, i, t) * Xgen[t, i, k, j] 
                  for k in 0:Kx[i]-1 
                  for j in 0:Nx[i, k]-1)
             )

  @constraint(m, wFuelC_E[t=0:T-1, i=0:I-1; fuelBased[i]],
              wFuelC[t, i] == 
              fuelCostW(mD, i, t) * sum(heat_w[t, i, j]
                                for j in 0:N[i]-1) 
             )

  @constraint(m, zFuelC_E[t=0:T-1, i=0:I-1; fuelBased[i]],
              zFuelC[t, i] == 
              sum(fuelCostZ(mD, i, t) * heat_z[t, i, k, j]
              for k in 0:Kz[i]-1 for j in 0:Nz[i, k]-1)
             )

  @constraint(m, xFuelC_E[t=0:T-1, i=0:I-1; fuelBased[i]],
              xFuelC[t, i] == 
              fuelCostW(mD, i, t) * sum(heat_x[t, i, k, j] 
                                                for k in 0:Kx[i]-1
                                                for j in 0:Nx[i, k]-1
                                               )
             )
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
  @constraint(m, co2Budget,
              sum(co2OverallYr[t] for t in 0:T-1)  <= 
            (co22010 + co22050) * 0.5 * 41 - co2_2010_2015
           )
  #: retirement based on "old" age
  @constraint(m, wOldRetE[t=1:T-1, i=0:I-1],
              wOldRet[t, i] == 
              (
                retCostW(mD, i, t, N[i]-1) +
                #: no cap
                365*24*saleLost(mD, kind, time age)
              ) * w[t, i, N[i]]
             )

  @constraint(m, zOldRetE[t=1:T-1, i=0:I-1, k=0:Kz[i]-1],
              zOldRet[t, i, k] == 
              (
                retCostW(mD, i, t, N[i]-1) + 
                #: no cap
                365*24*saleLost(mD, i, t, N[i]-1)
              ) * z[t, i, k, Nz[i, k]]
             )


  @constraint(m, xOldRetE[t=1:T-1, i=0:I-1, k=0:Kx[i]-1],
              xOldRet[t, i, k] == 
              (
                retCostW(mD, i, t, Nx[i, k]-1) +
                #: no cap
                365*24*saleLost(mD, i, t, Nx[i, k]-1)
              ) * x[t, i, k, Nx[i, k]]
             )

  #: forced retirement
  @constraint(m, wRet_E[i=0:I-1, j=1:N[i]-1],
              wRet[i, j] == 
              sum(
              ( #: can we just put the age directly into sales?
              retCostW(mD, i, t, j) + 365*24*saleLost(mD, i, t, j)
              ) * uw[t, i, j] for t in 0:T-1)
             )

  @constraint(m, zRet_E[i=0:I-1, k=0:Kz[i]-1, j=1:Nz[(i,k)]-1],
              zRet[i, k, j] 
              == sum(
              (
                retCostW(mD, i, t, min(j, N[i]-1)) + 
                365*24*saleLost(mD, i, t, j)
              ) * uz[t, i, k, j] for t in 0:T-1)
              )


  @constraint(m, xRet_E[i=0:I-1, k=0:Kx[i]-1, j=1:Nx[(i, k)]-1],
              xRet[i, k, j] == 
              sum(
              (
                retCostW(mD, i, t, j) +
                365*24*saleLost(mD, i, t, j)
              ) * ux[t, i, k, j] for t in 0:T-1)
             )

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


  @constraint(m, termCwE[i=0:I-1, j=0:N[i]-1],
              termCw[i, j] == 
              #retCostW(mD, t, i, N[i]-1) 
              (retCostW(mD, i, T-1, j) + 365*24*saleLost(mD, i, t, j))
              * W[T-1, i, j] 
             )

  @constraint(m, termCxE[i=0:I-1, k=0:Kx[i]-1, 
                         j=0:Nx[i,k]-1],
              termCx[i, k, j] == 
              # retCostW(mD, T-1, i, j) * 
              ( retCostW(mD, i, T-1, j) +
              365*24*saleLost(mD, i, t, j) ) *
              X[T-1, i, k, j]
             )

  @constraint(m, termCzE[i=0:I-1, k=0:Kz[i]-1, 
                         j=0:Nz[i, k]-1],
              termCz[i, k, j] == 
                (
                retCostW(mD, i, T-1, min(j, N[i]-1)) + 
                365*24*saleLost(mD, i, t, j)
                )
              retCostW(mD, T-1, i, min(j, N[i]-1)) * Z[T-1, i, k, j]
             )

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

  @constraint(m, windRatioI[t=1:T-1, i = 8:10],
              sum(X[t, i, k, 0] 
                 for k in 0:Kx[i]-1
                )
              == 
              sum(X[t, windIdx, k, 0] * windRatio[i + 1]
                  for k in 0:Kx[windIdx]-1
                  ))
  #: only applied on new allocations

end


"""
    genObj()
Generates the objective function.
"""
function genObj!(m::JuMP.Model, mS::modSets, mD::modData)
  @info "Setting objective.."
  xOcap = m[:xOcap]
  co2OverallYr = m[:co2Overall]
  termCost = m[:termCost]

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
end

function fixDelayed0(m::JuMP.Model)
  x = m[:x]
  maxDelay = maximum(values(xDelay))
  for t in -maxDelay:-1
    for i in 0:I-1
      for k in 0:Kx[i]-1
        fix(x[t, i, k, 0], 0, force=true)
      end
    end
  end
end
#
