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
mutable struct coef
  initCap::Array{Float64, 2} #: MW
  capC::Array{Float64, 2} #: $/kW
  fixC::Array{Float64, 2} #: $/kWyr
  varC::Array{Float64, 2} #: $/MWh
  cFac::Array{Float64, 2}
  decomC::Array{Float64, 2}  #: $/MW
  elecSaleC::Array{Float64, 2} #: cent/kWh
  heatRw::Array{Float64, 2} #: BTu/kWh
  heatRx::Array{Float64, 2}
  function coef(inputFile::String)
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


mutable struct attr
  servLife::Array{Float64} #: yr
  carbInt::Array{Float64} #: kgCO2/MMBTU
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

