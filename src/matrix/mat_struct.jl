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
    s = xf["Sheet1"]
    # set arrays
    ic = s["B3:BT13"]
    cc = s["B17:CS27"]
    fc = s["B31:CS41"]
    vc = s["B45:CS55"]
    cf = s["B59:CS69"]
    dc = s["C87:C97"]
    es = s["B100:CS100"]
    ho = s["B104:BI114"]
    hn = s["B118:CS128"]
    new(ic, cc, fc, vc, cf, dc, es, ho, hn)
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
  #: Decomission
  decomC::Array{Float64, 2}  #: $/MW
  #: Sales
  elecSaleC::Array{Float64, 2} #: cent/kWh
  function costAttr(inputFile::String)
    XLSX.openxlsx(inputFile, mode="r") do xf
    println("The data has been assumed to be in page 1")
    # set sheet
    s = xf["Sheet1"]
    # set arrays
    ic = s["B3:BT13"]
    cc = s["B17:CS27"]
    fc = s["B31:CS41"]
    vc = s["B45:CS55"]
    cf = s["B59:CS69"]
    dc = s["C87:C97"]
    es = s["B100:CS100"]
    ho = s["B104:BI114"]
    hn = s["B118:CS128"]
    new(ic, cc, fc, vc, cf, dc, es, ho, hn)
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
  function attr(inputFile::String)
    XLSX.openxlsx(inputFile, mode="r") do xf
    println("The data has been assumed to be in page 2")
    # set sheet
    s = xf["Sheet2"]
    sl = s["C9:C19"]
    ci = s["D9:D19"]
    new(sl, ci)
    end
  end
end

