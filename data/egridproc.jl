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
    #print(typeof(aka))
    #print(typeof(uid))
    #print("\n")
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
                    dl = d[genidG] # use this key entry instead
                    @info "Found $(genid) $(genidG) nrematch=$(ngidremtch)"
                    global ngidremtch+=1
                    val = dl[4]
                    st = "matchx"
                    planB = true
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
filter!(row -> row.SECTOR == "Electric Utility", opdf)

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
sort!(dfCap, :GENYRONL)
# make the years into strings
transform!(dfCap, [:GENYRONL] => (x->string.(x)) => :GENYRONL)
# transpose
permutedims(dfCap, 1)


# heat rates
# drop the rows without hr
dropmissing!(opdf, :HR)
# group by prime-mover-fuel
grpf = groupby(opdf, :PMPF)
# create weighted average hr dataframe
dfWavgHr = DataFrame(:GENYRONL=>minyr:maxyr)
for df in grpf
    gname = df[1, :PMPF].*"_WAVGHR"
    yrHr = combine(groupby(df, :GENYRONL),
                   [:NAMEPCAP, :HR] => ((x,y)->sum((x./sum(x)).*y)) 
                   => Symbol(gname))
    # yrHr = DataFrame(:GENYRONL=>Int64[], Symbol(gname)=>Float64[])
    # for g in groupby(df, :GENYRONL)
    #     y = g[1, :GENYRONL]
    #     g0 = select(g, :NAMEPCAP => (x->x./sum(x))=> :W, :HR)
    #     g0 = select(g0, [:W, :HR] => ((x, y)->x.*y) => :WHR)
    #     s = sum(g0[:, :WHR])
    #     push!(yrHr, (y, s))
    # end
    global dfWavgHr = outerjoin(dfWavgHr, yrHr, on=:GENYRONL)
end

# sort by year
sort!(dfWavgHr, :GENYRONL)

transform!(dfWavgHr, :GENYRONL => (x->string.(x))=> :GENYRONL)

# transpose
permutedims(dfWavgHr, 1)
