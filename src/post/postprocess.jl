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


