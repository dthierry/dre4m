#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################


#inputExcel_cap_mat = 
#"/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"

#inputExcel = 
#"/Users/dthierry/Projects/plantsAnl/data/Util_Master_Input_File.xlsx"

# Age - 1, 2, 3, ....
# We can have parameters as function of the year, age

# What are the inputs?

# Things that come in array form with time/age dimension and tech.
# capital cost
# fixed o and m
# variable o and m
# fuel_mat
# capacity factor
# heat rate old
# heat rate new
# cost of electricty
# cost of decomission
# demand matrix
# market share
# wind ratio

# array form only as function of tech
# service life
# carbon intensity
#
using XLSX

mutable struct timeAttr
  #: initial capacity
  initCap::Array{Float64, 2} #: MW
  #: demand
  nachF::Array{Float64, 2} #: MWh
  #: capacity Factor
  cFac::Array{Float64, 2}
  #: heat rate(s)
  heatRw::Array{Float64, 2} #: BTu/kWh
  heatRx::Array{Float64, 2} #: BTu/kWh
  function timeAttr(inputFile::String)
    XLSX.openxlsx(inputFile, mode="r") do xf
    println("The data has been assumed to be in page 1")
    # set sheet
    s = xf["timeAttr"]
    # set arrays
    ic = s["B3:BT13"]
    nh = s["B17:CS17"]
    cf = s["B21:CS31"] 
    ho = s["B35:BI45"]
    hn = s["B49:CS59"]
    new(ic, 
        nh, 
        cf, 
        ho, 
        hn)
    end
  end
end

mutable struct costAttr
  #: the Kapital
  capC::Array{Float64, 2} #: $/kW
  #: Fixed O&M
  fixC::Array{Float64, 2} #: $/kWyr
  #: Variabl O&M
  varC::Array{Float64, 2} #: $/MWh
  #: Sales
  elecSaleC::Array{Float64, 2} #: cent/kWh
  #: Fuel
  fuelC::Array{Float64, 2}
  #: Decomission (time invariant)
  decomC::Array{Float64, 2}  #: $/MW
  function costAttr(inputFile::String)
    XLSX.openxlsx(inputFile, mode="r") do xf
    println("The data has been assumed to be in page 1")
    # set sheet
    s = xf["costAttr"]
    # set arrays
    cc = s["B3:CS13"]
    fc = s["B17:CS27"]
    vc = s["B31:CS41"]
    es = s["B44:CS44"]
    fc = s["B48:CS58"]
    dc = s["E62:E72"]
    new(cc, fc, vc, es, fc, dc)
    end
  end
end

mutable struct invrAttr
  servLife::Array{Float64} #: yr
  carbInt::Array{Float64} #: kgCO2/MMBTU
  # util_cfs = capacity_factors
  #: Discount rate
  discountR::Float64
  #: Heat rate increase
  heatIncR::Float64
  #: Loan period 
  loanP::Int64
  function invrAttr(inputFile::String)
    XLSX.openxlsx(inputFile, mode="r") do xf
    println("The data has been assumed to be in page 2")
    # set sheet
    s = xf["invrAttr"]
    sl = s["C9:C19"]
    ci = s["D9:D19"]
    dr = s["B21"]
    hri = s["B22"]
    lp = s["B23"]
    new(sl, ci, dr, hri, lp)
    end
  end
end

