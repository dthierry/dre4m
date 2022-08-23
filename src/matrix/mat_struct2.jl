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
    
    kinds_z::Array{Int64}
    kinds_x::Array{Int64}

    fuelBased::Array{Bool}
    co2Based::Array{Bool}
    bLoadTech::Array{Bool}

    # util_cfs = capacity_factors
    #: Discount rate
    discountR::Float64
    #: Heat rate increase
    heatIncR::Float64
    #: Loan period 
    loanP::Int64
    function invrAttr(inputFile::String)
        XLSX.openxlsx(inputFile, mode="r") do xf
            sR = xf["reference"]
            cif = sR["C18"]
            # set sheet
            s = xf["invrAttr"]
            sl = s[sR["B17"]]
            sl = vec(sl)
            ci = s[sR["B18"]].*cif
            kz = s[sR["B22"]]
            kx = s[sR["B23"]]
            #booleans
            fb = s[sR["B24"]]
            cb = s[sR["B25"]]
            bl = s[sR["B26"]]

            dr = s[sR["B19"]]
            hri = s[sR["B20"]]
            lp = s[sR["B21"]]

            new(sl, 
                ci, 
                kz, 
                kx,
                fb,
                cb,
                bl,
                dr, 
                hri, 
                lp)
        end
    end
end

# we keep the rf function but the fallback goes to the matrix
struct absForm
    delay
    servLinc
    mCc
    mFc
    mVc
    mHr
    mEm
    mFu

    bCc
    bFc
    bVc
    bHr
    bEm
    bFu
    function absForm(inputFile::String, kRef::String, m9Ref::String)
        mCc = Dict((0,0)=>-9999e0)
        mFc = Dict((0,0)=>-9999e0)
        mVc = Dict((0,0)=>-9999e0)
        mHr = Dict((0,0)=>-9999e0)
        mEm = Dict((0,0)=>-9999e0)
        mFu = Dict((0,0)=>-9999e0)

        bCc = Dict((0,0)=>-9999)
        bFc = Dict((0,0)=>-9999)
        bVc = Dict((0,0)=>-9999)
        bHr = Dict((0,0)=>-9999)
        bEm = Dict((0,0)=>-9999)
        bFu = Dict((0,0)=>-9999)
        
        delay = Dict((0,0)=>0) #: leading time
        sLinc = Dict((0,0)=>0e0) 

        XLSX.openxlsx(inputFile, mode="r") do xf
            #: read the reference cells
            sR = xf["reference"] 
            kIdx = sR[kRef] # this was B22
            matIdx = sR[m9Ref]  # this was B27

            #: use the references to read the actual matrix 
            s = xf["invrAttr"]
            kinds_z = s[kIdx]
            In = length(kinds_z)
            
            #:
            mat9999 = s[matIdx]
            offset = 1
            i = 0
            for kn in kinds_z
                k = 0
                for j in (offset+1):(offset+kn)
                    delay[(i, k)] = mat9999[j,1]>0 ? mat9999[j,1] : 0
                    sLinc[(i, k)] = mat9999[j,2]>0 ? mat9999[j,2] : 0
                    mCc[(i, k)] = mat9999[j, 3]
                    bCc[(i, k)] = floor(mat9999[j, 4])
                    mVc[(i, k)] = mat9999[j, 5]
                    bVc[(i, k)] = floor(mat9999[j, 6])
                    mFc[(i, k)] = mat9999[j, 7]
                    bFc[(i, k)] = floor(mat9999[j, 8])
                    mHr[(i, k)] = mat9999[j, 9]
                    bHr[(i, k)] = floor(mat9999[j, 10])
                    mEm[(i, k)] = mat9999[j, 11]
                    bEm[(i, k)] = floor(mat9999[j, 12])
                    mFu[(i, k)] = mat9999[j, 13]
                    bFu[(i, k)] = floor(mat9999[j, 14])
                    k += 1
                end
                offset += kn + 1
                i += 1
            end
        end
        new(delay,
            sLinc,
            mCc, 
            mFc, 
            mVc, 
            mHr, 
            mEm, 
            mFu, 
            bCc, 
            bFc, 
            bVc, 
            bHr, 
            bEm, 
            bFu)
    end
end



##

