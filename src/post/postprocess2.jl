# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
using XLSX
using JuMP
using Dates
function writeRes(m::JuMP.Model, mS::modSets, mD::modData, pr::prJrnl)
    fname = pr.fname
    T = mS.T
    I = mS.I
    N = mS.N
    Kz = mS.Kz
    Kx = mS.Kx

    no_z = sum(values(Kz)) == 0 ? true : false 
    no_x = sum(values(Kx)) == 0 ? true : false 

    xDelay = mD.nwf.delay
    zDelay = mD.rtf.delay

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

    w = m[:w]
    z = m[:z]
    x = m[:x]

    uw = m[:uw]
    uz = m[:uz]
    ux = m[:ux]

    xD = Dict()
    uxD = Dict()
    for t in 0:T
        for i in 0:I-1
            for k in 0:Kx[i]-1
                for j in 0:T-1
                    if t >= (j+xDelay[i, k])
                        xD[t, i, k, j] = value(x[t,i,k,j])
                        uxD[t, i, k, j] = value(ux[t,i,k,j])
                    else
                        xD[t, i, k, j] = 0e0
                        uxD[t, i, k, j] = 0e0
                    end
                end
            end
        end
    end

    zD = Dict()
    uzD = Dict()
    for t in 0:T
        for i in 0:I-1
            for k in 0:Kz[i]-1
                for j in 0:N[i]-1
                    if t >= (zDelay[i, k])
                        zD[t, i, k, j] = value(z[t,i,k,j])
                        uzD[t, i, k, j] = value(uz[t,i,k,j])
                    else
                        zD[t, i, k, j] = 0e0
                        uzD[t, i, k, j] = 0e0
                    end
                end
            end
        end
    end

    zTrans = m[:zTrans]
    xAlloc = m[:xAlloc]
    wE = m[:wE]
    zE = m[:zE]
    xE = m[:xE]

    W = m[:W]
    Z = m[:Z]
    X = m[:X]

    Wgen = m[:Wgen]
    Zgen = m[:Zgen]
    Xgen = m[:Xgen]
    npv = m[:npv]
    termCost = m[:termCost]
    co2OverallYr = m[:co2OverallYr]

    wRet = m[:wRet]
    zRet = m[:zRet]
    xRet = m[:xRet]

    zOcap = m[:zOcap]
    xOcap = m[:xOcap]

    wFixOnM = m[:wFixOnM]
    wVarOnM = m[:wVarOnM]

    zFixOnM = m[:zFixOnM]
    zVarOnM = m[:zVarOnM]

    xFixOnM = m[:xFixOnM]
    xVarOnM = m[:xVarOnM]

    wFuelC = m[:wFuelC]
    zFuelC = m[:zFuelC]
    xFuelC = m[:xFuelC]

    termCz = m[:termCz]
    termCx = m[:termCx]

    wLat = m[:wLat]
    zLat = m[:zLat]
    xLat = m[:xLat]

    kinds_z = mD.ia.kinds_z
    kinds_x = mD.ia.kinds_x

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
            sheet["C1"] = ["elmAge=$(j)" for j in 0:N[i]-1]
            sheet["A2", dim=1] = collect(0:T)
            #sheet["B2", dim=1] = [1 for i in 0:T]
            for t in 0:T
                ts = string(t + 2)
                sheet["C"*ts] = [value(uw[t, i, j]) for j in 0:N[i]-1]
            end
            for k in 0:Kz[i]-1
                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "z_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                sheet["C1"] = ["rtfAge=$(j)" for j in 0:(N[i]-1)]
                sheet["A2", dim=1] = collect(0:T)
                for t in 0:T
                    ts = string(t + 2)
                    sheet["C"*ts] = [zD[t, i, k, j] for j in 0:N[i]-1]
                end

                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "uz_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                #sheet["B1"] = "i = PC"
                sheet["C1"] = ["elRfAge=$(j)" for j in 0:N[i]-1]
                sheet["A2", dim=1] = collect(0:T)
                for t in 0:T
                    ts = string(t + 2)
                    sheet["C"*ts] = [uzD[t, i, k, j] for j in 0:N[i]-1]
                end
            end
            for k in 0:Kx[i]-1
                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "x_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                # sheet["B1"] = "i = PC"
                sheet["C1"] = ["newAge=$(j)" for j in 0:T-1]
                sheet["A2", dim=1] = collect(0:T)
                # sheet["B2", dim=1] = [1 for i in 0:T]
                for t in 0:T
                    ts = string(t + 2)
                    sheet["C"*ts] = [xD[t, i, k, j] for j in 0:T-1]
                end

                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "ux_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                # sheet["B1"] = "i = PC"
                sheet["C1"] = ["eNwAge=$(j)" for j in 0:T-1]
                sheet["A2", dim=1] = collect(0:T)
                # sheet["B2", dim=1] = [1 for i in 0:T]
                for t in 0:T
                    ts = string(t + 2)
                    sheet["C"*ts] = [uxD[t, i, k, j] for j in 0:T-1]
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
        sheet["B2", dim=1] = [d[t+1] for t in 0:T-1]
    end

    XLSX.openxlsx(fname*"_em.xlsx", mode="w") do xf
        global sh = 0
        for i in 0:I-1
            if !co2Based[i+1]
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
                sheet["B1"] = ["rtfAge=$(j)" for j in 0:(N[i]-1)]
                sheet["A2", dim=1] = collect(0:T-1)
                for t in 0:T-1
                    ts = string(t + 2)
                    sheet["B"*ts] = [value(zE[t, i, k, j]) for j in 0:(N[i]-1)]
                end
            end
            for k in 0:Kx[i]-1
                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "xe_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                sheet["B1"] = ["newAge=$(j)" for j in 0:T-1]
                sheet["A2", dim=1] = collect(0:T)
                for t in 0:T-1
                    ts = string(t + 2)
                    sheet["B"*ts] = [value(xE[t, i, k, j]) for j in 0:T-1]
                end
            end
        end
    end


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
            sheet["C1"] = ["elmAge=$(j)" for j in 0:N[i]-1]
            sheet["A2", dim=1] = collect(0:T)
            #sheet["B2", dim=1] = [1 for i in 0:T]
            for t in 0:T-1
                ts = string(t + 2)
                sheet["C"*ts] = [value(uw[t, i, j]) for j in 0:N[i]-1]
            end
            for k in 0:Kz[i]-1
                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "z_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                sheet["C1"] = ["rtfAge=$(j)" for j in 0:N[i]-1]
                sheet["A2", dim=1] = collect(0:T)
                for t in 0:T-1
                    ts = string(t + 2)
                    sheet["C"*ts] = [value(Z[t, i, k, j]) for j in 0:N[i]-1]
                end

                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "uz_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                #sheet["B1"] = "i = PC"
                sheet["C1"] = ["elRfAge=$(j)" for j in 0:N[i]-1]
                sheet["A2", dim=1] = collect(0:T)
                for t in 0:T
                    ts = string(t + 2)
                    sheet["C"*ts] = [uzD[t, i, k, j] for j in 0:N[i]-1]
                end
            end
            for k in 0:Kx[i]-1
                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "x_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                # sheet["B1"] = "i = PC"
                sheet["C1"] = ["newAge=$(j)" for j in 0:T-1]
                sheet["A2", dim=1] = collect(0:T)
                # sheet["B2", dim=1] = [1 for i in 0:T]
                for t in 0:T-1
                    ts = string(t + 2)
                    sheet["C"*ts] = [value(X[t, i, k, j]) for j in 0:T-1]
                end

                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "ux_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                # sheet["B1"] = "i = PC"
                sheet["C1"] = ["eNwAge=$(j)" for j in 0:T-1]
                sheet["A2", dim=1] = collect(0:T)
                # sheet["B2", dim=1] = [1 for i in 0:T]
                for t in 0:T
                    ts = string(t + 2)
                    sheet["C"*ts] = [uxD[t, i, k, j] for j in 0:T-1]
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
        sheet["B2", dim=1] = [d[t+1] for t in 0:T-1]
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
                sheet["C1"] = ["elRfAge=$(j)" for j in 0:N[i]-1]
                sheet["A2", dim=1] = collect(0:T)
                for t in 0:T
                    ts = string(t + 2)
                    sheet["C"*ts] = [value(zTrans[t, i, k, j]) for j in 0:N[i]-1]
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
            sheet["C1"] = ["age=$(j)" for j in 0:N[i]-1]
            sheet["C2"] = [value(wRet[i, j]) for j in 0:N[i]-1]

            for k in 0:Kz[i]-1
                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "z_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                sheet["C1"] = ["rtfAge=$(j)" for j in 0:N[i]-1]
                sheet["C2"] = [value(zRet[i, k, j]) for j in 0:N[i]-1]

            end
            for k in 0:Kx[i]-1
                global sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "x_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                sheet["C1"] = ["newAge=$(j)" for j in 0:T-1]
                sheet["C2"] = [value(xRet[i, k, j]) for j in 0:T-1]

            end
        end

    end

    XLSX.openxlsx(fname*"_ret_1.xlsx", mode="w") do xf
        row = 2
        sheet = xf[1]
        XLSX.rename!(sheet, "cost_by_age")
        sheet["A1"] = "time"
        max_age = [maximum(values(N)), maximum(values(N)), maximum(values(T))]
        max_age = maximum(max_age)
        max_age = max_age
        sheet["B1"] = [j for j in 0:max_age-1]
        for i in 0:I-1
            #: Existing
            sheet["A$(row)"] = "w_$(i)"
            sheet["B$(row)"] = [value(wRet[i, j]) for j in 0:N[i]-1]
            row += 1
            #: RF
            for k in 0:Kz[i]-1
                sheet["A$(row)"] = "z_$(i)_$(k)"
                sheet["B$(row)"] = [value(zRet[i, k, j]) for j in 0:N[i]-1]
                row += 1
            end
            #: New
            for k in 0:Kx[i]-1
                sheet["A$(row)"] = "x_$(i)_$(k)"
                sheet["B$(row)"] = [value(xRet[i, k, j]) for j in 0:T-1]
                row += 1
            end
        end
    end

    #: What is this function for?
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
            lVals = [value(wRet[i, j]) for j in 0:N[i]-1]
            lRelAge = [j/(N[i]-1) for j in 0:N[i]-1]
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
                lVals = [value(zRet[i, k, j]) for j in 0:N[i]-1]
                lRelAge = [j/(N[i]-1) for j in 0:N[i]-1]
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
                lVals = [value(xRet[i, k, j]) for j in 0:T-1]
                lRelAge = [j/(T-1) for j in 0:T-1]
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
            lVals = [sum(value(uw[t, i, j]) for t in 0:T-1) for j in 0:N[i]-1]
            lRelAge = [j/(N[i]-1) for j in 0:N[i]-1]
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
                lVals = [sum(uzD[t, i, k, j] for t in 0:T-1) for j in 0:N[i]-1]
                lRelAge = [j/(N[i]-1) for j in 0:N[i]-1]
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
                lVals = [sum(uxD[t, i, k, j] for t in 0:T-1) for j in 0:T-1]
                lRelAge = [j/(T-1) for j in 0:T-1]
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
        max_age = [maximum(values(N)), maximum(values(N)), T]
        max_age = maximum(max_age)
        max_age = max_age
        sheet["B1"] = [j for j in 0:max_age-1]
        for i in 0:I-1
            #: Existing
            sheet["A$(row)"] = "t"
            sheet["B$(row)"] = [j/(N[i]-1) for j in 0:N[i]-1]
            sheet["A$(row+1)"] = "w_$(i)"
            sheet["B$(row+1)"] = [value(wRet[i, j]) for j in 0:N[i]-1]
            row += 2
            #: RF
            for k in 0:Kz[i]-1
                sheet["A$(row)"] = "t"
                sheet["B$(row)"] = [j/(N[i]-1) for j in 0:N[i]-1]
                sheet["A$(row+1)"] = "z_$(i)_$(k)"
                sheet["B$(row+1)"] = [value(zRet[i, k, j]) for j in 0:N[i]-1]
                row += 2
            end
            #: New
            for k in 0:Kx[i]-1
                sheet["A$(row)"] = "t"
                sheet["B$(row)"] = [j/(T-1) for j in 0:T-1]
                sheet["A$(row+1)"] = "x_$(i)_$(k)"
                sheet["B$(row+1)"] = [value(xRet[i, k, j]) for j in 0:T-1]
                row += 2
            end
        end
    end

    XLSX.openxlsx(fname*"_stats.xlsx", mode="w") do xf
        shn = 1
        sheet = xf[shn]
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
        wrsum = sum(value(wRet[i, j]) for i in 0:I-1 for j in 0:N[i]-1)
        rrsum = no_z ? 0e0 : sum(value(zRet[i, k, j]) for i in 0:I-1 
                               for k in 0:Kz[i]-1 for j in 0:N[i]-1) 
        xrsum = no_x ? 0e0 : sum(value(xRet[i, k, j]) for i in 0:I-1 
                                 for k in 0:Kx[i]-1 for j in 0:T-1)
        sheet["B4"] = wrsum + rrsum + xrsum 
        sheet["B5"] = value(termCost)
        sheet["B6"] = sum(value(co2OverallYr[t]) for t in 0:T-1)
        fname0 = Dates.format(pr.initT, "eyymmdd-HHMMSS")
        sheet["B7"] = fname0

        XLSX.addsheet!(xf)
        shn += 1
        sheet = xf[shn]
        XLSX.rename!(sheet, "ccost_retro")
        sheet["A1"] = "tech"
        sheet["B1"] = "capital M\$"
        row = 2
        for i in 0:I-1
            #: RF
            for k in 0:Kz[i]-1
                sheet["A$(row)"] = "z_$(i)_$(k)"
                sheet["B$(row)"] = no_z ? 0e0 : sum(value(zOcap[t, i, k]) 
                                                    for t in 0:T-1)
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_z ? 0e0 : sum(value.(zOcap))
        end
        ####
        XLSX.addsheet!(xf)
        row = 2
        shn+=1
        sheet = xf[shn]
        XLSX.rename!(sheet, "ccost_new")
        sheet["A1"] = "tech"
        sheet["B1"] = "capital M\$"
        for i in 0:I-1
            #: New
            for k in 0:Kx[i]-1
                sheet["A$(row)"] = "x_$(i)_$(k)"
                sheet["B$(row)"] = no_x ? 0e0 : sum(value(xOcap[t, i, k]) 
                                                    for t in 0:T-1) 
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_x ? 0e0 : sum(value.(xOcap)) 
        end

        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        XLSX.rename!(sheet, "old_capacity")
        row = 2
        sheet["A1"] = "cap old (last)"
        sheet["B1"] = "GW"
        for i in 0:I-1
            sheet["A$(row)"] = "w_$(i)"
            sheet["B$(row)"] = sum(value(w[T, i, j]) 
                                   for j in 0:N[i]-1) 
            row += 1
        end

        sheet["A$(row)"] = "sum"
        sheet["B$(row)"] = sum(value.(w)) 
  
        row = 2
        sheet["C1"] = "retirement old"
        sheet["D1"] = "GW"
        for i in 0:I-1
            sheet["C$(row)"] = "uw_$(i)"
            sheet["D$(row)"] = sum(value(uw[t, i, j]) 
                                   for t in 0:T-1 for j in 0:N[i]-1) 
            row += 1
        end
        sheet["C$(row)"] = "sum"
        sheet["D$(row)"] = sum(value.(uw)) 

        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "retrof_cap")
        sheet["A1"] = "allocations retrofit"
        sheet["B1"] = "GW"
        for i in 0:I-1
            #: Existing
            #: RF
            for k in 0:Kz[i]-1
                sheet["A$(row)"] = "z_$(i)_$(k)"
                # N[i] because we only consider the years of existing cap
                sheet["B$(row)"] = no_z ? 0e0 : sum(value(zTrans[t, i, k, j]) 
                                                    for t in 0:T-1 
                                                    for j in 0:N[i]-1) 
                row += 1
            end
            sheet["A$(row)"] = "sum"
            # N[i] because we only consider the years of existing cap
            sheet["B$(row)"] = no_z ? 0e0 : sum(value.(zTrans))
        end
        row = 2
        sheet["C1"] = "retirement retrofit"
        sheet["D1"] = "GW"
        for i in 0:I-1
            #: Existing
            #: RF
            for k in 0:Kz[i]-1
                sheet["C$(row)"] = "uz_$(i)_$(k)"
                sheet["D$(row)"] = no_z ? 0 : sum(uzD[t, i, k, j] 
                                                  for t in 0:T-1 
                                                  for j in 0:N[i]-1) 
                row += 1
            end
            sheet["C$(row)"] = "sum"
            sheet["D$(row)"] = no_z ? 0 : sum(values(uzD))
        end
        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "new_cap")
        sheet["A1"] = "allocations new"
        sheet["B1"] = "GW"
        for i in 0:I-1
            #: new
            for k in 0:Kx[i]-1
                sheet["A$(row)"] = "x_$(i)_$(k)"
                sheet["B$(row)"] = no_x ? 0 : sum(value(xAlloc[t, i, k]) 
                                                  for t in 0:T-1) 
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_x ? 0 : sum(value.(xAlloc))
        end

        row = 2 
        sheet["C1"] = "retirement new"
        sheet["D1"] = "GW"
        for i in 0:I-1
            #: new
            for k in 0:Kx[i]-1
                sheet["C$(row)"] = "ux_$(i)_$(k)"
                sheet["D$(row)"] = no_x ? 0 : sum(uxD[t, i, k, j] 
                                                  for t in 0:T-1 
                                                  for j in 0:T-1) 
                row += 1
            end
            sheet["C$(row)"] = "sum"
            sheet["D$(row)"] = no_x ? 0 : sum(values(uxD))
        end

        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "wVoNm")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            sheet["A$(row)"] = "w_$(i)"
            sheet["B$(row)"] = sum(value(wVarOnM[t, i]) for t in 0:T-1)
            row += 1
        end
        sheet["A$(row)"] = "sum"
        sheet["B$(row)"] = sum(value.(wVarOnM))
        ####
        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "zVoNm")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            for k in 0:Kz[i]-1
                sheet["A$(row)"] = "z_$(i)_$(k)"
                sheet["B$(row)"] = no_z ? 0e0 : sum(value(zVarOnM[t,i,k]) 
                                                    for t in 0:T-1)
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_z ? 0e0 : sum(value.(zVarOnM))
        end
        ####
        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "xVoNm")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            for k in 0:Kx[i]-1
                sheet["A$(row)"] = "x_$(i)_$(k)"
                sheet["B$(row)"] = no_x ? 0e0 : sum(value(xVarOnM[t,i,k]) 
                                                    for t in 0:T-1) 
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_x ? 0e0 : sum(value.(xVarOnM))
        end
        ####
        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "wFoNm")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            sheet["A$(row)"] = "w_$(i)"
            sheet["B$(row)"] = sum(value(wFixOnM[t, i]) for t in 0:T-1)
            row += 1
        end
        sheet["A$(row)"] = "sum"
        sheet["B$(row)"] = sum(value.(wFixOnM))
        ####
        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "zFoNm")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            for k in 0:Kz[i]-1
                sheet["A$(row)"] = "z_$(i)_$(k)"
                sheet["B$(row)"] = no_z ? 0e0 : sum(value(zFixOnM[t,i,k]) 
                                                    for t in 0:T-1)
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_z ? 0e0 : sum(value.(zFixOnM))
        end
        ####
        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "xFoNm")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            for k in 0:Kx[i]-1
                sheet["A$(row)"] = "x_$(i)_$(k)"
                sheet["B$(row)"] = no_x ? 0e0 : sum(value(xFixOnM[t,i,k]) 
                                                    for t in 0:T-1) 
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_x ? 0e0 : sum(value.(xFixOnM)) 
        end

        ####
        ####
        XLSX.addsheet!(xf)
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "wRet")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            sheet["A$(row)"] = "w_$(i)"
            sheet["B$(row)"] = sum(value(wRet[i, j]) for j in 0:N[i]-1)
            row += 1
        end
        sheet["A$(row)"] = "sum"
        sheet["B$(row)"] = sum(value.(wRet))
        ###
        XLSX.addsheet!(xf)
        ###
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "zRet")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            for k in 0:Kz[i]-1
                sheet["A$(row)"] = "z_$(i)_$(k)"
                sheet["B$(row)"] = no_z ? 0e0 : sum(value(zRet[i,k,j]) 
                                                    for j in 0:N[i]-1)
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_z ? 0e0 : sum(value.(zRet))
        end
        ####
        ###
        XLSX.addsheet!(xf)
        ###
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "xRet")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            for k in 0:Kx[i]-1
                sheet["A$(row)"] = "x_$(i)_$(k)"
                sheet["B$(row)"] = no_z ? 0e0 : sum(value(xRet[i,k,j]) 
                                                    for j in 0:T-1)
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_z ? 0e0 : sum(value.(xRet))
        end
        ####
        ####
        XLSX.addsheet!(xf)
        ###
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "fuel&em")
        sheet["A1"] = "old"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            if !fuelBased[i+1]
                continue
            end
            sheet["A$(row)"] = "w_$(i)"
            sheet["B$(row)"] = sum(value(wFuelC[t, i]) for t in 0:T-1)
            row += 1
        end
        sheet["A$(row)"] = "sum"
        sheet["B$(row)"] = sum(value.(wFuelC))
        row = 2
        sheet["C1"] = "retrofit"
        sheet["D1"] = "M\$"
        for i in 0:I-1
            if !fuelBased[i+1]
                continue
            end
            for k in 0:Kz[i]-1
                sheet["C$(row)"] = "z_$(i)_$(k)"
                sheet["D$(row)"] = no_z ? 0e0 : sum(value(zFuelC[t, i, k]) 
                                                    for t in 0:T-1)
                row += 1
            end
            sheet["C$(row)"] = "sum"
            sheet["D$(row)"] = no_z ? 0e0 : sum(value.(zFuelC))
        end
        row = 2
        sheet["E1"] = "new"
        sheet["F1"] = "M\$"
        for i in 0:I-1
            if !fuelBased[i+1]
                continue
            end
            for k in 0:Kx[i]-1
                sheet["E$(row)"] = "x_$(i)_$(k)"
                sheet["F$(row)"] = no_x ? 0e0 : sum(value(xFuelC[t, i, k]) 
                                                    for t in 0:T-1)
                row += 1
            end
            sheet["E$(row)"] = "sum"
            sheet["F$(row)"] = no_x ? 0e0 : sum(value.(xFuelC))
        end
        ####
        row = 2
        sheet["G1"] = "old"
        sheet["H1"] = "tCO2"
        for i in 0:I-1
            if !co2Based[i+1]
                continue
            end
            sheet["G$(row)"] = "w_$(i)"
            sheet["H$(row)"] = sum(value(wE[t, i, j]) for t in 0:T-1 
                                   for j in 0:N[i]-1)
            row += 1
        end
        sheet["G$(row)"] = "sum"
        sheet["H$(row)"] = sum(value.(wE))
        row = 2
        sheet["I1"] = "retrofit"
        sheet["J1"] = "tCO2"
        for i in 0:I-1
            if !co2Based[i+1]
                continue
            end
            for k in 0:Kz[i]-1
                sheet["I$(row)"] = "z_$(i)_$(k)"
                sheet["J$(row)"] = no_z ? 0e0 : sum(value(zE[t, i, k, j]) 
                                                    for t in 0:T-1 
                                                    for j in 0:N[i]-1)
                row += 1
            end
            sheet["I$(row)"] = "sum"
            sheet["J$(row)"] = no_z ? 0e0 : sum(value.(zE))
        end
        row = 2
        sheet["K1"] = "new"
        sheet["L1"] = "tCO2"
        for i in 0:I-1
            if !co2Based[i+1]
                continue
            end
            for k in 0:Kx[i]-1
                sheet["K$(row)"] = "x_$(i)_$(k)"
                sheet["L$(row)"] = no_x ? 0e0 : sum(value(xE[t, i, k, j]) 
                                                    for t in 0:T-1 
                                                    for j in 0:T-1)
                row += 1
            end
            sheet["K$(row)"] = "sum"
            sheet["L$(row)"] = no_x ? 0e0 : sum(value.(xE))
        end
        ####
        XLSX.addsheet!(xf)
        ###
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "Lat")
        sheet["A1"] = "kind"
        sheet["A2"] = "existing"
        sheet["A3"] = "retrofit"
        sheet["A4"] = "new"

        sheet["B1"] = "RetirePotentialOvrll M\$"
        sheet["B2"] = value(wLat) 
        sheet["B3"] = value(zLat)
        sheet["B4"] = value(xLat) 

        ###
        XLSX.addsheet!(xf)
        ###
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "termCz")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            for k in 0:Kz[i]-1
                sheet["A$(row)"] = "z_$(i)_$(k)"
                sheet["B$(row)"] = no_z ? 0e0 : sum(value(termCz[i, k, j]) 
                                                    for j in 0:N[i]-1)
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_z ? 0e0 : sum(value.(termCz))
        end

        XLSX.addsheet!(xf)
        ###
        shn+=1
        sheet = xf[shn]
        row = 2
        XLSX.rename!(sheet, "termCx")
        sheet["A1"] = "tech"
        sheet["B1"] = "M\$"
        for i in 0:I-1
            for k in 0:Kx[i]-1
                sheet["A$(row)"] = "x_$(i)_$(k)"
                sheet["B$(row)"] = no_x ? 0e0 : sum(value(termCx[i, k, j]) 
                                                    for j in 0:T-1)
                row += 1
            end
            sheet["A$(row)"] = "sum"
            sheet["B$(row)"] = no_x ? 0e0 : sum(value.(termCx))
        end

    end

    XLSX.openxlsx(fname*"_gen.xlsx", mode="w") do xf
        sh = 0
        for i in 0:I-1
            sh += 1
            XLSX.addsheet!(xf)
            sheet = xf[sh]
            XLSX.rename!(sheet, "w_"*string(i))
            sheet["A1"] = "time"
            sheet["C1"] = ["age=$(j)" for j in 0:N[i]-1]
            sheet["A2", dim=1] = collect(0:T)
            for t in 0:T-1
                ts = string(t + 2)
                sheet["C"*ts] = [value(Wgen[t, i, j]) for j in 0:N[i]-1]
            end
            for k in 0:Kz[i]-1
                sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "z_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                sheet["C1"] = ["rtfAge=$(j)" for j in 0:N[i]-1]
                sheet["A2", dim=1] = collect(0:T)
                for t in 0:T-1
                    ts = string(t + 2)
                    sheet["C"*ts] = [value(Zgen[t, i, k, j]) for j in 0:N[i]-1]
                end
            end
            for k in 0:Kx[i]-1
                sh += 1
                XLSX.addsheet!(xf)
                sheet = xf[sh]
                XLSX.rename!(sheet, "x_"*string(i)*"_"*string(k))
                sheet["A1"] = "time"
                sheet["C1"] = ["newAge=$(j)" for j in 0:T-1]
                sheet["A2", dim=1] = collect(0:T)
                for t in 0:T-1
                    ts = string(t + 2)
                    sheet["C"*ts] = [value(Xgen[t, i, k, j]) for j in 0:T-1]
                end
            end
        end
        sh += 1
        XLSX.addsheet!(xf)
        sheet = xf[sh]
        XLSX.rename!(sheet, "d")
        sheet["A1"] = "time"
        sheet["B1"] = "demand"
        sheet["A2", dim=1] = collect(0:T)
        sheet["B2", dim=1] = [d[t+1] for t in 0:T-1]
    end
end

