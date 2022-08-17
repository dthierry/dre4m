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
            # set sheet
            #
        sR = xf["reference"]
        icf = sR["C2"]
        nf = sR["C3"]
        hrf = sR["C5"]
        hr2f = sR["C6"]
        @info "timeAttr facts are as follows: 
        icf: $(icf) nf: $(nf) hrf: $(hrf)  hr2: $(hr2f)"
            s = xf["timeAttr"]
            # set arrays
            ic = s[sR["B2"]].*icf # initial
            nh = s[sR["B3"]].*nf # nachtf
            cf = s[sR["B4"]] # cap fact
            ho = s[sR["B5"]].*hrf # vint hr
            hn = s[sR["B6"]].*hr2f # new hr
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
            sR = xf["reference"]
            ccf = sR["C8"]
            fcf = sR["C9"]
            vcf = sR["C10"]
            esf = sR["C11"]
            fuf = sR["C12"]
            dcf = sR["C13"]
            @info "costAttr facts are as follows: 
            cc: $(ccf) fc: $(fcf) vc: $(vcf)  es: $(esf)
            fu: $(fuf) dc: $(dcf)"
            # set sheet
            s = xf["costAttr"]
            # set arrays
            cc = s[sR["B8"]].*ccf
            fc = s[sR["B9"]].*fcf
            vc = s[sR["B10"]].*vcf
            es = s[sR["B11"]].*esf
            fu = s[sR["B12"]].*fuf
            dc = s[sR["B13"]].*dcf
            new(cc, fc, vc, es, fu, dc)
        end
    end
end

mutable struct invrAttr
  servLife::Vector{Int64} #: yr
  carbInt::Array{Float64} #: kgCO2/MMBTU
  # util_cfs = capacity_factors
  #: Discount rate
  discountR::Float64
  #: Heat rate increase
  heatIncR::Float64
  #: Loan period 
  loanP::Int64
  #: Delay
  delayZ::Dict{Tuple{Int64, Int64}, Int64}
  delayX::Dict{Tuple{Int64, Int64}, Int64}
  function invrAttr(inputFile::String)
    XLSX.openxlsx(inputFile, mode="r") do xf
        sR = xf["reference"]
        cif = sR["C16"]
    # set sheet
    s = xf["invrAttr"]
    sl = s[sR["B15"]]
    sl = vec(sl)
    ci = s[sR["B16"]].*cif
    dr = s[sR["B17"]]
    hri = s[sR["B18"]]
    lp = s[sR["B19"]]
    dx = Dict((0,0)=>1)
    dz = Dict((0,0)=>1)
    new(sl, ci, dr, hri, lp, dx, dz)
    end
  end
end

