################################################################################
#                    Copyright 2022, UChicago LLC. Argonne                     #
#       This Source Code form is subject to the terms of the MIT license.      #
################################################################################
# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80 tw=80

# created @dthierry 2022
# log:
# 1-17-23 added some comments

"""
    modSets(inputFile::String)
Initializes the time sets of the model.
inputs are the time and technology cardinality, time invariant attributes 
(invrAttr), retrofit form (absForm) and new plant form (absForm).
"""
struct modSets
    T::Int64 #: time-cardinality
    I::Int64 #: tech-cardinality
    Kz::Dict{Int64, Int64} #: Tech for subprocess i (retrofit)
    Kx::Dict{Int64, Int64} #: Tech for subprocess i (new)
    N::Dict{Int64, Int64} #: Age-cardinality for tech-i
    Nz::Dict{Tuple{Int64, Int64}, Int64} #: Retrofit age
    Nx::Dict{Tuple{Int64, Int64}, Int64} #: New plant age
    # Constructor
    function modSets(
            T::Int64, 
            I::Int64, 
            ia::invrAttr, 
            rtf::absForm, 
            nwf::absForm
        )

    servLife = ia.servLife
    kinds_z = ia.kinds_z
    kinds_x = ia.kinds_x

    zServLinc = rtf.servLinc
    xServLinc = nwf.servLinc

    Kz = Dict(i => kinds_z[i+1] for i in 0:I-1)
    Kx = Dict(i => kinds_x[i+1] for i in 0:I-1)

    N = Dict(i => ia.ninput[i+1] for i in 0:I-1)
    #: N = Dict(i => servLife[i+1] for i in 0:I-1)
    Nz = Dict((i,k) => N[i] 
              + floor(Int, servLife[i+1]*zServLinc[i, k]) 
            for i in 0:I-1 for k in 0:Kz[i]-1)
    #: this is assuming the service life does not increase for new capacity
    Nx = Dict((i,k) => servLife[i+1] for i in 0:I-1 for k in 0:Kx[i]-1)

    new(T, I, Kz, Kx, N, Nz, Nx)
  end
end

"""
    modData()
This is where all the useful data for the model gets aggregated.
"""
struct modData
  ta::timeAttr
  ca::costAttr
  ia::invrAttr
  rtf::absForm
  nwf::absForm
  misc::miscParam
end

