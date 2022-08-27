#vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80 tw=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
# implement changes of how we look at age
using JuMP

"""
    genModel(mS::modSets, modData::modData)::JuMP.Model
Generates model with variables and constraints.
"""
function genModel(mS::modSets, 
        mD::modData, 
        pr::prJrnl; 
        no_rf::Bool=false,
        no_delay_z::Bool=false,
        no_delay_x::Bool=false)::JuMP.Model
    #: There is model sets: mS, and
    # model data: mD.
    #: Initial set
    @info "Generating model..."
    T = mS.T
    I = mS.I
    N = mS.N
    Nx = mS.Nx
    Nz = mS.Nz
    Kz = mS.Kz

    if no_rf == true
        for k in keys(Kz)
            Kz[k] = 0
        end
    end

    Kx = mS.Kx

    servLife = mD.ia.servLife

    zDelay = mD.rtf.delay
    if no_delay_z
        for k in keys(zDelay)
            zDelay[k] = 0
        end
    end

    xDelay = mD.nwf.delay
    if no_delay_x
        for k in keys(xDelay)
            xDelay[k] = 0
        end
    end

    fuelBased = mD.ia.fuelBased
    co2Based = mD.ia.co2Based
    bLoadTech = mD.ia.bLoadTech

    initCap = mD.ta.initCap
    d = mD.ta.nachF
    maxDelay = maximum(values(xDelay))
    cFactW = mD.ta.cFac
    size_cf = size(cFactW)
    cFactZ = zeros((size_cf[1], size_cf[2], 1))
    cFactX = zeros((size_cf[1], size_cf[2], 1))

    jrnl = j_log_f
    pr.caller = @__FILE__
    jrnlst!(pr, jrnl)

    #: Model creation
    m = Model()
    # Variables
    # this goes to N just because we need to constrain z at N-1
    # existing asset (GWh)
    @variable(m,
              w[t=0:T, i=0:I-1,
                j=0:N[i]-1]
              >= 0e0
             )

    # retired existing asset
    @variable(m, uw[t = 0:T, i = 0:I-1,
                    j = 0:N[i]-1]
              >= 0e0
             )

    # new asset
    @variable(m, x[t = 0:T,
                   i = 0:I-1, k = 0:Kx[i]-1,
                   j = 0:T; t>=(j+xDelay[i, k])]
              >= 0e0
             )
    #: made a ficticious point Nx so we can know how much is retired because it
    #: becomes too old
    #
    @variable(m,
              xAlloc[t=0:T, i=0:I-1, k=0:Kx[i]-1]
              >= 0e0)

    # retired new asset
    @variable(m, ux[t = 0:T,
                    i = 0:I-1, k = 0:Kx[i]-1,
                    j = 0:T;
                    t >= (j+xDelay[i, k])]
              >= 0)
    # can't retire at j = 0

    # retrofitted asset
    @variable(m,
              z[t=0:T, i=0:I-1, k=0:Kz[i]-1,
                j=0:N[i]-1;
                t >= zDelay[i, k]]
              >= 0)
    #: we have to recognize the fact that no retrofit tally can be kept at
    # any point in time that is between 0 and the zDelay amount.

    #: the retrofit can't happen at the end of life of a plant, i.e., j goes from
    #: 0 to N[i]-12
    #: the retrofit can't happen at the beginning of life of a plant, i.e. j = 0
    #: made a ficticious point Nxj so we can know how much is retired because it
    #: becomes too old

    @variable(m,
              zTrans[t = 0:T, i = 0:I-1, k = 0:Kz[i]-1,
                     j = 0:N[i]-1]
              >= 0)
    #: as opposed to "z", the zTrans variable can be defined from T=0

    # retired retrofit
    @variable(m,
              uz[t = 0:T, i = 0:I-1, k = 0:Kz[i]-1,
                 j = 0:N[i]-1; t >= zDelay[i,k]]
              >= 0)
    # can't retire at the first year of retrofit, jk = 0
    # can't retire at the last year of retrofit, i.e. jk = |Nxj|
    #: no retirements at the last age (n-1), therefore only goes to n-2

    # Effective capacity old
    @variable(m, W[t=0:T-1, i=0:I-1,
                   j=0:N[i]-1])

    @variable(m,
              Z[t=0:T-1, i=0:I-1, k=0:Kz[i]-1,
                j=0:N[i]-1])
    # Effective capacity new
    @variable(m,
              X[t=0:T-1,
                i=0:I-1, k=0:Kx[i]-1,
                j=0:T-1]
             )

    #: hey let's just create effective generation variables instead
    #: it seems that the capacity factors are the same regardless of
    #: us having retrofits, new capacity, etc.
    yrHr = 24* 365.  # hours in a year

    @variable(m,
              Wgen[t=0:T-1, i=0:I-1,
                   j=0:N[i]-1]
             )

    @variable(m,
              Zgen[t=0:T-1, i=0:I-1, k=0:Kz[i]-1,
                   j=0:N[i]-1]
             )

    @variable(m,
              Xgen[t=0:T-1, i=0:I-1, k=0:Kx[i]-1,
                   j=0:T-1])

    #: Generation (GWh)
    @variable(m, sGen[t = 1:T-1, i = 0:I-1]) #: supply generated

    @variable(m, heat_w[t = 0:T-1, i=0:I-1,
                        j = 0:N[i]-1; fuelBased[i+1]])

    @variable(m,
              heat_z[t=0:T-1,
                     i=0:I-1, k=0:Kz[i]-1,
                     j=0:N[i]-1; fuelBased[i+1]])

    @variable(m,
              heat_x[t=0:T-1,
                     i=0:I-1, k=0:Kx[i]-1,
                     j=0:T-1; fuelBased[i+1]])
    # Carbon emission (tCO2)
    @variable(m,
              wE[t = 0:T-1, i = 0:I-1,
                 j = 0:N[i]-1; co2Based[i+1]]
              >= 0e0
             )
    #: ♪ Ah&eM
    @variable(m,
              zE[t=0:T-1, i=0:I-1, k=0:Kz[i]-1,
                 j=0:N[i]-1; co2Based[i+1]]
              >= 0e0
             )

    @variable(m,
              xE[t=0:T-1, i=0:I-1, k=0:Kx[i]-1,
                 j=0:T-1; co2Based[i+1]]
              >= 0e0
             )


    # (overnight) Capital for new capacity
    @variable(m, xOcap[t=0:T-1, i=0:I-1, k=0:Kx[i]-1])

    # (overnight) Capital for retrofits
    @variable(m, zOcap[t=0:T-1, i=0:I-1, k=0:Kz[i]-1])
    # Operation and Maintenance for existing
    #: Do we have to partition this term?
    @variable(m, wFixOnM[t=0:T-1, i=0:I-1])
    @variable(m, wVarOnM[t=0:T-1, i=0:I-1])

    # O and M for retrofit
    @variable(m, zFixOnM[t=0:T-1, i=0:I-1, k=0:Kz[i]-1])
    @variable(m, zVarOnM[t=0:T-1, i=0:I-1, k=0:Kz[i]-1])
    # O and M for new
    @variable(m, xFixOnM[t=0:T-1, i=0:I-1, k=0:Kx[i]-1])
    @variable(m, xVarOnM[t=0:T-1, i=0:I-1, k=0:Kx[i]-1])
    # Fuel
    @variable(m, wFuelC[t=0:T-1, i=0:I-1; fuelBased[i+1]])

    @variable(m, zFuelC[t=0:T-1, i=0:I-1, k=0:Kz[i]-1; fuelBased[i+1]])

    @variable(m, xFuelC[t=0:T-1, i=0:I-1, k=0:Kx[i]-1; fuelBased[i+1]])

    @variable(m, co2OverallYr[t=0:T-1])

    # Natural "organic" retirement

    # "Forced" retirement
    @variable(m, wRet[i=0:I-1,
                      j=0:N[i]-1])
    @variable(m, zRet[i=0:I-1, k=0:Kz[i]-1,
                      j=0:N[i]-1])
    @variable(m, xRet[i=0:I-1, k=0:Kx[i]-1,
                      j=0:T])

    # Net present value
    @variable(m, npv) # ≥ 1000. * 2000.)

    #: Terminal cost
    @variable(m, termCw[i=0:I-1,
                        j=0:N[i]-1])

    @variable(m, termCx[i=0:I-1, k=0:Kx[i],
                        j=0:T-1])

    @variable(m, termCz[i=0:I-1, k=0:Kz[i]-1,
                        j=0:N[i]-1])

    @variable(m, termCost >= 0) #: overall

    ############ Constraint definition $$$$$$$$$$$$

    # w balance0
    @constraint(m,
                wbal[t = 0:T-1, i = 0:I-1,
                     j = 0:N[i]-1],
                w[t+1, i, j] == w[t, i, j]
                - uw[t, i, j]
                - sum(zTrans[t, i, k, j] for k in 0:Kz[i]-1)
               )
    #: the tally of assets of initial-age j

    # Zero out all the initial condition of the retrofits
    @constraint(m,
                ic_zE[i=0:I-1,
                      k=0:Kz[i]-1, j=0:N[i]-1],
                z[zDelay[i, k], i, k, j] == 0
               )
    # z balance
    @constraint(m,
                zBal[t=0:T-1, i=0:I-1, k=0:Kz[i]-1,
                     j=0:N[i]-1; t >= zDelay[i,k]],
                z[t+1, i, k, j] ==
                z[t, i, k, j]
                - uz[t, i, k, j]
                + zTrans[t-zDelay[i, k], i, k, j]
               )
    #: new allocations
    @constraint(m,
                xallocE[t=0:T-1,
                        i=0:I-1, k=0:Kx[i]-1,
                        j=0:T-1; t==(j+xDelay[i, k])],
                x[t, i, k, j] == xAlloc[t-xDelay[i, k], i, k]
               )

    #: leading time goes here
    # x balance
    @constraint(m,
                xbal[t = 0:T-1,
                     i = 0:I-1, k = 0:Kx[i]-1,
                     j = 0:T-1; t>=(j+xDelay[i, k])],
                x[t+1, i, k, j] == x[t, i, k, j] - ux[t, i, k, j]
               )

    # don't allow new assets to be retired at 0
    @constraint(m,
                initial_w_E[i = 0:I-1, j = 0:N[i]-1],
                w[0, i, j] == initCap[i+1, j+1]
               )
    # no initial plant at retirement age is allowed


    #: they have to be split as there are no forced retirements at time = 0
    @constraint(m, W_E[t=0:T-1, i=0:I-1, j=0:N[i]-1],
                W[t, i, j] ==
                w[t, i, j]
                - uw[t, i, j]
                - sum(zTrans[t, i, k, j] for k in 0:Kz[i]-1)
               )

  #: Effective capacity retrofit
  @constraint(m,
              Z_E0[t=0:T-1,
                   i=0:I-1, k=0:Kz[i]-1,
                   j=0:N[i]-1; t < zDelay[i,k]],
              Z[t, i, k, j] == 0e0
             )

  @constraint(m,
              Z_E[t=0:T-1,
                      i=0:I-1, k=0:Kz[i]-1,
                      j=0:N[i]-1; t >= zDelay[i,k]],
              Z[t, i, k, j] ==
              z[t, i, k, j] - uz[t, i, k, j]
              + zTrans[t-zDelay[i, k], i, k, j]
             )

  #:
  @constraint(m,
              X_E0[t=0:T-1,
                  i=0:I-1, k=0:Kx[i]-1,
                  j=0:T-1; t<(j+xDelay[i, k])],
              X[t, i, k, j] == 0e0
             )
  #: oi!, leading time needed here
  @constraint(m,
              X_E[t=0:T-1,
                  i=0:I-1, k=0:Kx[i]-1,
                  j=0:T-1; t>=(j+xDelay[i, k])],
              X[t, i, k, j] ==
              x[t, i, k, j] - ux[t, i, k, j]
             )

  #: these are the hard questions
  @constraint(m, WgEq[t=0:T-1, i=0:I-1, j=0:N[i]-1],
              Wgen[t, i, j] ==
              yrHr * cFactW[i+1, 1] * W[t, i, j]
              )

  @constraint(m, ZgEq[t=0:T-1, i=0:I-1, k=0:Kz[i]-1,
                      j=0:N[i]-1],
              Zgen[t, i, k, j] ==
              yrHr * cFactW[i+1, 1] * Z[t, i, k, j]
              )

  @constraint(m, XgEq[t=0:T-1, i=0:I-1, k=0:Kx[i]-1, j=0:T-1],
              Xgen[t, i, k, j] ==
              yrHr * cFactW[i+1, j+1] * X[t, i, k, j]
              )

  #: Generation (GWh)
  @constraint(m, sGenEq[t = 1:T-1, i = 0:I-1],
            (
            sum(Wgen[t, i, j] for j in 0:N[i]-1) +
            sum(Zgen[t, i, k, j] for k in 0:Kz[i]-1 for j in 0:N[i]-1
            ) +
            sum(Xgen[t, i, k, j] for k in 0:Kx[i]-1 for j in 0:T-1)
            ) == sGen[t, i]
            )

  # Demand
  @constraint(m,
              dcCon[t = 1:T-1],
              sum(sGen[t, i] for i in 0:I-1) >= d[t+1]
             )

  # Trade in the values for actual generation.
  # heatRateW(mD, kind, age, time, maxBaseAge)
  # the actual age is j+t
  @constraint(m,
              heat_w_E[t=0:T-1, i=0:I-1,
                       j=0:N[i]-1; fuelBased[i+1]],
              heat_w[t, i, j] ==
              Wgen[t, i, j] * wHeatRate(mD, i, j, t)
             )


  # the actual age is j+t
  @constraint(m,
              heat_z_E[t = 0:T-1, i = 0:I-1, k = 0:Kz[i]-1,
                       j = 0:N[i]-1; fuelBased[i+1]],
              heat_z[t, i, k, j] ==
              Zgen[t, i, k, j] * zHeatRate(mD, i, k, j, t)
             )

  # the actual age is t-j
  @constraint(m,
              heat_x_E[t=0:T-1, i=0:I-1, k=0:Kx[i]-1,
                       j=0:T-1; fuelBased[i+1]],
              heat_x[t, i, k, j] ==
              Xgen[t, i, k, j] * xHeatRate(mD, i, k, j, t)
             )

  @constraint(m,
              e_wCon[t=0:T-1, i=0:I-1,
                     j=0:N[i]-1; co2Based[i+1]],
              wE[t, i, j] == heat_w[t, i, j] * wCarbonInt(mD, i)
             )

  @constraint(m,
              e_zCon[t = 0:T-1, i = 0:I-1, k =0:Kz[i]-1,
                     j=0:N[i]-1; co2Based[i+1]],
              zE[t, i, k, j] ==
              heat_z[t, i, k, j] * devCarbonInt(mD, i, k, form="R")
             )

  @constraint(m,
              e_xCon[t=0:T-1, i=0:I-1, k=0:Kx[i]-1,
                     j=0:T-1; co2Based[i+1]],
              xE[t, i, k, j] ==
              heat_x[t, i, k, j] * devCarbonInt(mD, i, k, form="X")
             )

  @constraint(m, xOcapE[t=0:T-1, i=0:I-1, k=0:Kx[i]-1],
              xOcap[t, i, k] == devCapCost(mD, i, k, t)*xAlloc[t, i, k]
             )

  @constraint(m, zOcapE[t=0:T-1, i=0:I-1, k=0:Kz[i]-1],
              zOcap[t, i, k] == sum(
                                 devCapCost(mD, i, k, t, form="R")*
                                 zTrans[t, i, k, j]
                                 for j in 0:N[i]-1
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
              zFixOnM_E[t=0:T-1, i=0:I-1, k=0:Kz[i]-1],
              zFixOnM[t, i, k] ==
              sum(devFixCost(mD, i, k, t, form="R") * Z[t, i, k, j]
                  for j in 0:N[i]-1 #: only related to the base age
                    ))

  @constraint(m,
              zVarOnM_E[t=0:T-1, i=0:I-1, k=0:Kz[i]-1],
              zVarOnM[t, i, k] ==
              sum(devVarCost(mD, i, k, t, form="R") * Zgen[t, i, k, j]
                  for j in 0:N[i]-1 #: only related to the base age
                    ))


  @constraint(m,
              xFixOnM_E[t=0:T-1, i=0:I-1, k=0:Kx[i]-1],
              xFixOnM[t, i, k] ==
              sum(devFixCost(mD, i, k, t, form="X")*X[t, i, k, j]
                  for j in 0:T-1)
             )

  @constraint(m,
              xVarOndM_E[t=0:T-1, i=0:I-1, k=0:Kx[i]-1],
              xVarOnM[t, i, k] ==
              sum(devVarCost(mD, i, k, t, form="X")*Xgen[t, i, k, j]
                  for j in 0:T-1)
             )

  @constraint(m, wFuelC_E[t=0:T-1, i=0:I-1; fuelBased[i+1]],
              wFuelC[t, i] ==
              wFuelCost(mD, i, t) * sum(heat_w[t, i, j]
                                for j in 0:N[i]-1)
             )

  @constraint(m, zFuelC_E[t=0:T-1, i=0:I-1, k=0:Kz[i]-1;
                          fuelBased[i+1]],
              zFuelC[t, i, k] ==
              sum(devFuelCost(mD, i, k, t, form="R") * heat_z[t, i, k, j]
                  for j in 0:N[i]-1)
             )

  @constraint(m, xFuelC_E[t=0:T-1, i=0:I-1, k=0:Kx[i]-1;
                          fuelBased[i+1]],
              xFuelC[t, i, k] ==
              sum(devFuelCost(mD, i, k, t, form="X") * heat_x[t, i, k, j]
                  for j in 0:T-1)
             )

  @constraint(m, co2OverallYrE[t=0:T-1],
              co2OverallYr[t] ==
              sum(wE[t, i, j] for i in 0:I-1
                  for j in 0:N[i]-1 if co2Based[i+1])
              + sum(zE[t, i, k, j]
                    for i in 0:I-1
                    for k in 0:Kz[i]-1
                    for j in 0:N[i]-1
                    if co2Based[i+1])
              + sum(xE[t, i, k, j]
                    for i in 0:I-1
                    for k in 0:Kx[i]-1
                    for j in 0:T-1 if co2Based[i+1])
             )

  #: retirement based on "old" age

  #: forced retirement
  # age is j+t
  @constraint(m, wRet_E[i=0:I-1, j=0:N[i]-1],
              wRet[i, j] ==
              sum(
              (retCost(mD, i, t, j+t) + 365*24*saleLost(mD, i, t, j))
              * uw[t, i, j] for t in 0:T-1)
             )

  @constraint(m, zRet_E[i=0:I-1, k=0:Kz[i]-1,
                        j=0:N[i]-1],
              zRet[i, k, j]
              == sum(
              (retCost(mD, i, t, j+t) + 365*24*saleLost(mD, i, t, j))
              * uz[t, i, k, j] for t in 0:T-1 if t >= zDelay[i,k])
              )


  @constraint(m, xRet_E[i=0:I-1, k=0:Kx[i]-1,
                        j=0:T-1],
              xRet[i, k, j] ==
              sum(
              (retCost(mD, i, t, t-j) + 365*24*saleLost(mD, i, t, j))
              * ux[t, i, k, j] for t in 0:T-1 if t >= (j+xDelay[i, k]))
             )

  @constraint(m, npv_e,
              npv ==
              # overnight
              sum(zOcap[t, i, k]
                  for t in 0:T-1
                  for i in 0:I-1
                  for k in 0:Kz[i]-1)
              + sum(xOcap[t, i, k]
                    for t in 0:T-1
                    for i in 0:I-1
                    for k in 0:Kx[i]-1)
              # op and maintenance (fixed + variable)
              #: existing
              + sum(
                    wFixOnM[t, i] + wVarOnM[t, i]
                    for t in 0:T-1 for i in 0:I-1)
              #: retrofit
              + sum(
                    zFixOnM[t, i, k] + zVarOnM[t, i, k]
                    for t in 0:T-1
                    for i in 0:I-1
                    for k in 0:Kz[i]-1)
              #: new
              + sum(
                    xFixOnM[t, i, k] + xVarOnM[t, i, k]
                    for t in 0:T-1
                    for i in 0:I-1
                    for k in 0:Kx[i]-1
                   )
              # cost of fuel
              + sum(
                    wFuelC[t, i]
                    for t in 0:T-1
                    for i in 0:I-1 if fuelBased[i+1])
              + sum(
                    zFuelC[t, i, k]
                    for t in 0:T-1
                    for i in 0:I-1
                    for k in 0:Kz[i]-1 if fuelBased[i+1])
              + sum(
                    xFuelC[t, i, k]
                    for t in 0:T-1
                    for i in 0:I-1
                    for k in 0:Kx[i]-1 if fuelBased[i+1])
              + sum(wRet[i, j]
                    for i in 0:I-1
                    for j in 0:N[i]-1)
              + sum(zRet[i, k, j]
                    for i in 0:I-1
                    for k in 0:Kz[i]-1
                    for j in 0:N[i]-1)
              + sum(xRet[i, k, j]
                    for i in 0:I-1
                    for k in 0:Kx[i]-1
                    for j in 0:T-1)
             )

  @constraint(m, termCwE[i=0:I-1, j=0:N[i]-1],
              termCw[i, j] ==
              (retCost(mD, i, T-1, min(j+T-1, N[i]-1)) +
               365*24*saleLost(mD, i, T-1, j)
              )
              * W[T-1, i, j]
             )

  @constraint(m, termCxE[i=0:I-1, k=0:Kx[i]-1,
                         j=0:T-1],
              termCx[i, k, j] ==
              ( retCost(mD, i, T-1, T-1-j) +
               365*24*saleLost(mD, i, T-1, T-1-j)
              ) *
              X[T-1, i, k, j]
             )

  @constraint(m, termCzE[i=0:I-1, k=0:Kz[i]-1,
                         j=0:N[i]-1],
              termCz[i, k, j] ==
              (
                retCost(mD, i, T-1, min(j+T-1, N[i]-1)) +
                365*24*saleLost(mD, i, T-1, T-1-j)
              ) * Z[T-1, i, k, j]
             )
    #: not accountable for investment decisions made before the
    # time horizon
  @constraint(m, termCE,
              termCost ==
              #sum(termCw[i, j]
              #    for i in 0:I-1
              #    for j in 0:N[i]-1)
              # +
              sum(termCx[i, k, j]
                    for i in 0:I-1
                    for k in 0:Kx[i]-1
                    for j in 0:T-1)
              + sum(termCz[i, k, j]
                    for i in 0:I-1
                    for k in 0:Kz[i]-1
                    for j in 0:N[i]-1)
             )

  function rLatentW(time, kind, age)
      sL = servLife
      return retCost(mD, kind, 1, -1)* exp((age-sL[kind+1])/sL[kind+1])
      # retirementCost_age_1 * exp((age-servLife)/servLife)
  end

  @variable(m, wLatRet[t=0:T-1, i=0:I-1,
                       j=0:N[i]-1;
                       (t+j) >= servLife[i+1] && !bLoadTech[i+1]])

  @constraint(m, wOldRetE[t=0:T-1, i=0:I-1,
                          j=0:N[i]-1;
                          (t+j)>=servLife[i+1] && !bLoadTech[i+1]],
              wLatRet[t,i,j] == w[t, i, j] * rLatentW(t, i, (t+j))
              #wLatRet[t,i,j] == w[t, i, j] * retCostW(mD, i, t,
              #                  min(1, max(31,N[i]-1 - t - j))))
             )
  #
  function rLatentZ(time, baseKind, kind, age)
      si = mD.rtf.servLinc
      sL = (i, k) -> floor(Int, servLife[i+1]*(1+si[i, k]))
      return retCost(mD, kind, 1, -1)*
      exp((age-sL(baseKind, kind))/sL(baseKind, kind))
  end

  @variable(m, zLatRet[t=0:T-1, i=0:I-1, k=0:Kz[i]-1,
                       j=0:N[i]-1;
                       (t+j) >= Nz[i,k] && t >= zDelay[i,k] && !bLoadTech[i+1]]
           )

  @constraint(m, zOldRetE[t=0:T-1, i=0:I-1, k=0:Kz[i]-1,
                          j=0:N[i]-1;
                          (t+j)>=Nz[i,k] && t>=zDelay[i,k] && !bLoadTech[i+1]],
              zLatRet[t, i, k, j] == z[t, i, k, j] * rLatentZ(t, i, k, (t+j))
             # zLatRet[t, i, k, j] == z[t, i, k, j]*retCostW(mD, i, t,
             #                        min(1, max(31,Nz[i,k]-1 - t - j)))
             )
  #
  function rLatentX(time, baseKind, kind, age)
      si = mD.nwf.servLinc
      sL = (i, k) -> floor(Int, servLife[i+1]*(1+si[i, k]))
      return retCost(mD, kind, 1, -1)*
      exp((age-sL(baseKind, kind))/sL(baseKind, kind))
  end

  @variable(m, xLatRet[t=0:T-1, i=0:I-1, k=0:Kx[i]-1,
                       j=0:T-1;
                       (t-j)>=Nx[i, k] && !bLoadTech[i+1]]
           )

  @constraint(m, xOldRetE[t=0:T-1, i=0:I-1, k=0:Kx[i]-1,
                          j=0:N[i]-1;
                          (t-j) >= Nx[i, k] && !bLoadTech[i+1]],
              xLatRet[t, i, k, j] == x[t, i, k, j] * rLatentX(t, i, k, (t-j))
              #xLatRet[t, i, k, j] == x[t, i, k, j]*retCostW(mD, i, t,
              #                      min(1, max(31,Nx[i,k]-1 - t + j)))
             )

  return m
end


"""
    genObj()
Generates the objective function.
"""
function genObj!(m::JuMP.Model, mS::modSets, mD::modData)
  @info "Setting objective.."
  T = mS.T
  I = mS.I
  N = mS.N
  Nx = mS.Nx
  Nz = mS.Nz
  Kz = mS.Kz
  Kx = mS.Kx
  zDelay = mD.rtf.delay
  xDelay = mD.nwf.delay

   bLoadTech = mD.ia.bLoadTech
  xOcap = m[:xOcap]
  npv = m[:npv]
  termCost = m[:termCost]
  wLatRet = m[:wLatRet]
  xLatRet = m[:xLatRet]
  zLatRet = m[:zLatRet]

  @expression(m, wLat, sum(wLatRet))
  @expression(m, zLat, sum(zLatRet[t, i, k, j]
                           for t in 0:T-1 for i in 0:I-1 for k in 0:Kz[i]-1
                           for j in 0:N[i]-1 if
                           (t+j)>=Nz[i,k] && t>=zDelay[i,k] && !bLoadTech[i+1])
             )
  @expression(m, xLat, sum(xLatRet[t, i, k, j]
                           for t in 0:T-1 for i in 0:I-1 for k in 0:Kx[i]-1
                           for j in 0:T-1 if (t-j)>=Nx[i,k] && !bLoadTech[i+1])
             )


  @objective(m, Min, (npv
                      + wLat
                      + xLat
                      + zLat
                      + (1e-6)*termCost
                     )/1e3)
end

"""
    fixDelayed0()
Fix the variables at times less than -1.
"""
function fixDelayed0!(m::JuMP.Model, mS::modSets, mD::modData)
  x = m[:x]
  I = mS.I
  Kx = mS.Kx
  xDelay = mD.nwf.delay
  #: find the maximum delay
  maxDelay = maximum(values(xDelay))
  for t in -maxDelay:-1
    for i in 0:I-1
      for k in 0:Kx[i]-1
          println("why are we calling this??")
        #fix(x[t, i, k, 0], 0, force=true)
      end
    end
  end
end


"""
  gridConWind()
Add the wind ratio constraint for new techs.
"""
function gridConWind!(
        m::JuMP.Model,
        mS::modSets,
        baseIdx::Int64,
        specRatio::Dict{Int64, Float64})
    xAlloc = m[:xAlloc]
    T = mS.T
    Kx = mS.Kx
    windIdx = baseIdx #: sometimes 7
    windRatio = specRatio
    specIdx = keys(specRatio)
    #: only applied on new allocations
    @constraint(m, windRatI[t=1:T-1, i in specIdx],
                sum(xAlloc[t, i, k] for k in 0:Kx[i]-1)
                ==
                sum(xAlloc[t, windIdx, k] * windRatio[i]
                    for k in 0:Kx[windIdx]-1)
               )
end

"""
    gridConBudget(m::JuMP.Model, mS::modSets)
Add the co2 budget constraint.
"""
function EmConBudget!(
        m::JuMP.Model,
        mS::modSets)
    #: raison d'être
    X = m[:X]
    T = mS.T
    #: magic numbers
    co22010 = 2.2584E+09
    # co2_2010_2015 = 10_515_700_000.0
    # Greenhouse Gas Inventory Data Explorer
    co2_2010_2019 = 19_315_983_000.0 # using the epa GHC
    co22050 = co22010 * 0.29
    #: Last term is a trapezoid minus the 2010-2015 gap
    @info("The budget: $((co22010 + co22050) * 0.5 * 41 - co2_2010_2019)")
    co2OverallYr = m[:co2OverallYr]
    @constraint(m, co2Budget,
                sum(co2OverallYr[t] for t in 0:T-1) <=
                (co22010 + co22050) * 0.5 * 41 - co2_2010_2019
               )
end



function gridConUppahBound!(m::JuMP.Model, mS::modSets)
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
  # Upper bound on some new techs
  T = mS.T
  I = mS.I
  N = mS.N
  Kz = mS.Kz
  Kx = mS.Kx
  xAlloc = m[:xAlloc]
  upperBoundDict = Dict(
                        "B" => 1000/1e3 * 0.59,
                        "N" => 1000/1e3 * 0.898,
                        "H" => 1000/1e3 * 0.42)
  #: Just do it directly using bounds on the damn variables
  for tech in keys(upperBoundDict)
    id = techToId[tech]
    for t in 0:T-1
      for k in 0:Kx[id]-1
        #for j in 0:Nx[id, k]
        set_upper_bound(xAlloc[t, id, k], upperBoundDict[tech])
        #end
      end
    end
  end
end


