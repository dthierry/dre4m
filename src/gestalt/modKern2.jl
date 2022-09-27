# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################


struct modSets
    T::Int64 #: time-cardinality
    I::Int64 #: tech-cardinality
    # Tech for subprocess i (retrofit)
    Kz::Dict{Int64, Int64}
    # Tech for subprocess i (new)
    Kx::Dict{Int64, Int64}
    #: Age-cardinality for tech-i
    N::Dict{Int64, Int64}
    #: Retrofit age
    Nz::Dict{Tuple{Int64, Int64}, Int64}
    #: New plant age
    Nx::Dict{Tuple{Int64, Int64}, Int64}
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
    # N = Dict(i => servLife[i+1] for i in 0:I-1)
    Nz = Dict((i,k) => N[i] 
              + floor(Int, servLife[i+1]*zServLinc[i, k]) 
            for i in 0:I-1 for k in 0:Kz[i]-1)
    # this is assuming the service life does not increase for new capacity
    Nx = Dict((i,k) => servLife[i+1] for i in 0:I-1 for k in 0:Kx[i]-1)

    new(T, I, Kz, Kx, N, Nz, Nx)
  end
end

"""
    modData()
This is where I aggregate all the useful data for the model.
"""
struct modData
  ta::timeAttr
  ca::costAttr
  ia::invrAttr
  rtf::absForm
  nwf::absForm
  misc::miscParam
end

