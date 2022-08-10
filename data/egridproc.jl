#vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80 tw=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################


using XLSX
using DataFrames

# egrids data
file = "./data/egrid2020_data.xlsx"

# import unit sheet
dfu = DataFrame(XLSX.readtable(file, 2)...)
# import generator sheet
dfg = DataFrame(XLSX.readtable(file, 3)...)
# import plant sheet
dfp = DataFrame(XLSX.readtable(file, 4)...)

# rename the columns
new_names = [dfu[1, i] for i in names(dfu)]
rename!(dfu, new_names)
deleteat!(dfu, 1)

new_names = [dfg[1, i] for i in names(dfg)]
rename!(dfg, new_names)
deleteat!(dfg, 1)

new_names = [dfp[1, i] for i in names(dfp)]
rename!(dfp, new_names)
deleteat!(dfp, 1)

function getAka(s::String)::String
    rm = match(r"([0-9]+)"i, s)
    if !(rm === nothing)
        return rm[1]
    else
        return s
    end
end

# hash map that contains list of unit id, op.stat. heat input by plant name
du = Dict()
oris0 = -22234
for row in eachrow(dfu)
    # plant name
    name = row["PNAME"]
    # oris code
    oris = row["ORISPL"]
    #@info row["SEQUNT20"]
    # unit id
    uid = string(row["UNITID"]) # always string
    aka = getAka(uid)
    t_aka = Tuple{String, String}((aka, uid))
    # unit operational status
    # sometimes these are "missing"
    ust = row["UNTOPST"] === missing ? "MS" : row["UNTOPST"]
    # unit prime mover
    upm = row["PRMVR"]
    # unit primary fuel
    upf = row["FUELU1"]
    # annual heat input
    uahi = row["HTIAN"] === missing ? -9999e0 : float(row["HTIAN"])
    # hash entry
    entry = [ust, upm, upf, uahi]
    if oris == oris0
        du[oris][uid] = entry
        push!(du[oris]["akas"], t_aka)
    else
        du[oris] = Dict(uid=>entry, "akas" => [t_aka])
        if oris == 79
            @info "yes!"
        end
        # avg uahi
    end
    global oris0 = oris
end
# create a back-up dictionary with the acc uhi so we can average
duhia = Dict()
for k in keys(du)
    upmfl = []
    for k2 in keys(du[k])
        if k2 != "akas"
            push!(upmfl, (du[k][k2][2], du[k][k2][3]))
        end
    end
    local d = Dict(k3=>[0e0, 0] for k3 in upmfl)
    for k2 in keys(du[k])
        if k2 != "akas"
            k3 = (du[k][k2][2], du[k][k2][3])
            d[k3][1] += du[k][k2][4]
            d[k3][2] += 1
        end
    end
    duhia[k] = d
end

# plant level hash table
dp = Dict()
for row in eachrow(dfp)
    name = row["ORISPL"]
    dp[name] = row["SECTOR"]
end

sectlist = []
npnooris = 0
uahilist = []
stat = []
norisunm = 0
ngidunmtch = 0
ngidremtch = 0
ngidnohope = 0
# upgrade generator
for row in eachrow(dfg)
    oris = row["ORISPL"]
    genid = row["GENID"]
    pname = row["PNAME"]
    gpm = row["PRMVR"]
    gpf = row["FUELG1"]
    ps = "unk" 
    try
        ps = dp[oris]
    catch y
        if isa(y, KeyError)
            @info "$(pname), $(oris), not found in the plant dict n=(npnooris)"
            global npnooris += 1
        end
    end
    push!(sectlist, ps)
    val = missing
    st = "unmatched"
    local d = Dict()
    try
        d = du[oris]
    catch y
        if isa(y, KeyError)
            @info "$(pname) $(oris) oris not found $(norisunm)"
            global norisunm += 1
        end
    end
    try
        dl = d[genid]
        val = dl[4]
        st = "matched"
    catch y
        if isa(y, KeyError)
            @info "\t ID $(genid)\t $(pname) $(oris)
            genid not found n=$(ngidunmtch)"
            global ngidunmtch += 1
            akaG = getAka(genid)
            akaL = d["akas"]
            planB = false
            for k in akaL
                # search for a match in the akas list
                if akaG == k[1] # found
                    genidG = k[2]
                    dl = d[genidG] # attempt to use this key entry instead
                    if isa(dl[3], Missing)
                        break
                    end
                    # this reduces the false maches
                    if (dl[2] == gpm) && (dl[3] == gpf) # only match mover&fuel
                        @info "Found $(genid) $(genidG) nrematch=$(ngidremtch)"
                        global ngidremtch+=1
                        val = dl[4]
                        st = "matchx"
                        planB = true
                    end
                end
            end
            # fetch the avg unit anual heat input
            if !planB
                try
                    acc = duhia[oris]
                    val = acc[(gpm,gpf)][1]/acc[(gpm,gpf)][2]
                    st = "avg"
                    @info "\tsome hope"
                catch
                    val = missing
                    st = "nohope"
                    global ngidnohope += 1
                    @info "$(oris) $(pname) $(genid) $(gpm) $(gpf)
                    no hope n=$(ngidnohope)"
                end
            end
        end
    end
    push!(uahilist, val)
    push!(stat, st)
end

@info "no oris plant match=$(npnooris)"
@info "no oris match =$(norisunm)"
@info "no gen id match =$(ngidunmtch)"
@info "no gen id match then rematch =$(ngidremtch)"
@info "no gen id match then matches with mov-fuel =$(ngidnohope)"
@info "no gen id match withouth hope=$(ngidunmtch-ngidremtch-ngidnohope)"

# insert the new columns
insertcols!(dfg, :SECTOR=>sectlist)
insertcols!(dfg, :UHI=>uahilist)
insertcols!(dfg, :STUHI=>stat)

# compute the heat rate
transform!(dfg, [:GENNTAN, :UHI] => ((a, b)->b./a) => :HR)

#remore some undesired values
# Inf
dfg[:, :HR] .= ifelse.(isinf.(coalesce.(dfg[:,:HR],1)), missing, dfg[:, :HR])
# NaNs
dfg[:, :HR] .= ifelse.(isnan.(coalesce.(dfg[:,:HR],1)), missing, dfg[:, :HR])
# negative
dfg[:, :HR] .= ifelse.(coalesce.(dfg[:,:HR], 10) .< 0, missing, dfg[:, :HR])

# add a column with prime_mover_prime_fuel
dfg[:, :PMPF] = dfg[:, "PRMVR"].*"_".*dfg[:,"FUELG1"]
# filter out only operating
#opdf = dfg[dfg.GENSTAT .== "OP", :]
opdf = filter(row -> row.GENSTAT == "OP", dfg)

# drop missing sector
dropmissing!(opdf, :SECTOR)

# filter out only electric utilities
filter!(row -> 
        row.SECTOR == "Electric Utility" ||
        row.SECTOR == "IPP CHP" ||
        row.SECTOR == "IPP Non-CHP", 
        opdf)

minyr = minimum(opdf[:, :GENYRONL])
maxyr = minimum(opdf[:, :GENYRONL])
#XLSX.writetable("df.xlsx", opdf)

# create dataframe groups
grpf = groupby(opdf, :PMPF)

#ng = get(grpf, (PMPF="CA_NG",), nothing)
# Capacity dataframe
dfCap = DataFrame(:GENYRONL=>minyr:maxyr)

# calculate the aggregated capacity
for df in grpf
    gname = df[1, :PMPF]
    yrCap = combine(groupby(df, :GENYRONL), 
                    :NAMEPCAP => sum => Symbol(gname))
    global dfCap = outerjoin(dfCap, yrCap, on=:GENYRONL)
end

# sort by year
sort!(dfCap, :GENYRONL, rev=true)
# make the years into strings
transform!(dfCap, [:GENYRONL] => (x->string.(x)) => :GENYRONL)
# transpose
dfCap = permutedims(dfCap, 1)
#XLSX.writetable("cap2.xlsx", dfCap)

# heat rates
# drop the rows without hr
opdf2 = dropmissing(opdf, :HR)
# group by prime-mover-fuel
grpf = groupby(opdf2, :PMPF)
# create weighted average hr dataframe
dfWavHr = DataFrame(:GENYRONL=>minyr:maxyr)
for df in grpf
    gname = df[1, :PMPF].*"_WAVGHR"
    yrHr = combine(groupby(df, :GENYRONL),
                   [:GENNTAN, :HR] => ((x,y)->sum((x./sum(x)).*y)) 
                   => Symbol(gname))
    # yrHr = DataFrame(:GENYRONL=>Int64[], Symbol(gname)=>Float64[])
    # for g in groupby(df, :GENYRONL)
    #     y = g[1, :GENYRONL]
    #     g0 = select(g, :NAMEPCAP => (x->x./sum(x))=> :W, :HR)
    #     g0 = select(g0, [:W, :HR] => ((x, y)->x.*y) => :WHR)
    #     s = sum(g0[:, :WHR])
    #     push!(yrHr, (y, s))
    # end
    global dfWavHr = outerjoin(dfWavHr, yrHr, on=:GENYRONL)
end

# sort by year
sort!(dfWavHr, :GENYRONL, rev=true)

transform!(dfWavHr, :GENYRONL => (x->string.(x))=> :GENYRONL)

# transpose
dfWavHr = permutedims(dfWavHr, 1)

#XLSX.writetable("hr2.xlsx", dfWavHr)

modelTech = ["PC", "CT", "CC", "P", "B", "N", "H", "W",  "SPV", "STH", "G"]
techFuel = Dict("PC"=>["BIT", "LIG", "SUB", "RC", "SGC", "COG"],
                "CT"=>["NG"],
                "CC"=>["NG"],
                "P"=>["DFO", "JF", "KER", "PC", "RG", "RFO", "WO"],
                "B"=>["OBG", "OBL", "OBS"],
                "N"=>["NUC"],
                "H"=>["WAT"],
                "W"=>["WND"],
                "SPV"=>["SUN"],
                "STH"=>["SUN"],
                "G"=>["GEO"])
techMover = Dict("PC"=>[], # empty means all
                "CT"=>["GT", "IC"],
                "CC"=>["CA", "CC", "CT", "ST"],
                "P"=>[],
                "B"=>[],
                "N"=>[],
                "H"=>["HY"],
                "W"=>["WT"],
                "SPV"=>["PV"],
                "STH"=>["CP", "OT", "ST"],
                "G"=>[])

# capacities
grpf = groupby(opdf, :FUELG1)
dC = Dict([i=>DataFrame() for i in modelTech])

for mT in modelTech
    d0 = dC[mT]
    for fG in techFuel[mT]
        fGd = get(grpf, (FUELG1=fG,), nothing)
        if isa(fGd, Nothing)
            @info "$(mT): fuel=$(fG) does not exist."
            continue
        end
        movers = techMover[mT]
        if length(movers) > 0
            for m in movers
                mGd = filter(:PRMVR=> x->x==m, fGd)
                append!(d0, mGd)
            end
        else
            append!(d0, fGd)
        end
    end
end

dfCap2 = DataFrame(:GENYRONL=>minyr:maxyr)
for mT in modelTech
    df = dC[mT]
    if size(df)[1] == 0
        continue
    end
    gname = mT
    yrHr = combine(groupby(df, :GENYRONL),
                   :NAMEPCAP => sum 
                   => Symbol(gname))
    global dfCap2 = outerjoin(dfCap2, yrHr, on=:GENYRONL)
end
# sort by year
sort!(dfCap2, :GENYRONL, rev=true)
transform!(dfCap2, :GENYRONL => (x->string.(x))=> :GENYRONL)
# transpose
dfCap2 = permutedims(dfCap2, 1)
XLSX.writetable("cap3.xlsx", dfCap2)

# heat rates
grpf = groupby(opdf2, :FUELG1)
dTech = Dict([i=>DataFrame() for i in modelTech])

for mT in modelTech
    d0 = dTech[mT]
    for fG in techFuel[mT]
        fGd = get(grpf, (FUELG1=fG,), nothing)
        if isa(fGd, Nothing)
            @info "$(mT): fuel=$(fG) does not exist."
            continue
        end
        movers = techMover[mT]
        if length(movers) > 0
            for m in movers
                mGd = filter(:PRMVR=> x->x==m, fGd)
                append!(d0, mGd)
            end
        else
            append!(d0, fGd)
        end
    end
end

dfWavHr2 = DataFrame(:GENYRONL=>minyr:maxyr)
for mT in modelTech
    df = dTech[mT]
    if size(df)[1] == 0
        continue
    end
    gname = mT*"_WA_HR"
    yrHr = combine(groupby(df, :GENYRONL),
                   [:GENNTAN, :HR] => ((x,y)->sum((x./sum(x)).*y)) 
                   => Symbol(gname))
    global dfWavHr2 = outerjoin(dfWavHr2, yrHr, on=:GENYRONL)
end
# sort by year
sort!(dfWavHr2, :GENYRONL, rev=true)
transform!(dfWavHr2, :GENYRONL => (x->string.(x))=> :GENYRONL)
# transpose
dfWavHr2 = permutedims(dfWavHr2, 1)

XLSX.writetable("hr3.xlsx", dfWavHr2)

# A technology is a combination of mover-fuel
# "Pulverized Coal PC" techs (with all movers, but typically just ST)
# BIT, LIG, SUB, RC, WC, SGC, COG 

# "Gas Turbine aka combustion turbine" (mover={IC})
# NG 

# "Combined Cycle" (mover={GT, IC})
# NG

# "Petroleum" (mover={CA, CT, GT, IC, ST})
# DFO, JF, KER, PC, RG, RFO, WO => PETROLEUM

# BFG, OG, TDF => OTHER FOSSIL

# "ALL NUKE" (mover={ST})
# NUC

# "Hydroelectric WAT" (mover={HY})
# WAT

# "B" (mover={IC})
# OBG, OBL, OBS

# "SPV" (moved={ST})
# SUN

# "STH" (not existing? mover={ST})
# SUN

# "Geothermal" mover={ST}
# GEO

# Pulverized Coal (PC)
# Natural Gas (NGGT)
# Natural Gas (NGCC)
# Petroleum (P)
# Biomass (B)
# Nuclear (N)
# Hydroelectric (H)
# On-shore wind (W)
# Solar PV (SPV)
# Solar Thermal (STH)
# Geothermal (G)
