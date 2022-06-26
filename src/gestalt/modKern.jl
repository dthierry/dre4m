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
  function modSets(f::aForm)
  #function modSets(T::Int64, 
  #                 I::Int64, 
  #                 kinds_z::Vector{Int64}, 
  #                 kinds_x::Vector{Int64}, 
  #                 servLife::Vector{Int64},
  #                 sLfIncr::Float64)
    kinds_z = f.kinds_z
    kinds_x = f.kinds_x

    Kz = Dict(i => kinds_z[i+1] for i in 0:I-1)
    Kx = Dict(i => kinds_x[i+1] for i in 0:I-1)
    N = Dict(i => servLife[i+1] for i in 0:I-1)
    Nz = Dict((i,k) => N[i] + floor(Int, servLife[i+1]*sLfIncr) 
            for i in 0:I-1 for k in 0:Kz[i]-1)
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
end
