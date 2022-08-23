#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################

abstract type aForm end

"""
   gridF
Data strucure that contains the structural information of the retrofits, new
 plants and so forth.
"""
mutable struct gridForm <: aForm
  #: kinds of retrofit for technology I
  kinds_x::Array{Int64}
  #: kinds of new plants for technology I
  kinds_z::Array{Int64}
  #: delay for the new plants
  xDelay::Dict{Tuple{Int, Int}, Int}
  #: delay for the retrofits
  zDelay::Dict{Tuple{Int, Int}, Int}
  #: if TRUE tech is based on fuel
  #fuelBased::Dict
  #: if TRUE tech fuel generates co2
  #co2Based::Dict
  function gridForm(I::Int64)
    kinds_x = zeros(Int32, I)
    kinds_z = zeros(Int32, I)
    xDelay = Dict((0, 0) => 0)
    zDelay = Dict((0, 0) => 0)
    fuelBased = Dict(i => false for i in 0:I-1)
    co2Based = Dict(i => false for i in 0:I-1)
    new(kinds_x, kinds_z, 
        xDelay, zDelay#, fuelBased, co2Based
       )
  end
end

