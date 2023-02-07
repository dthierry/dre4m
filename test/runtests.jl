# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################

using Test
using dre4m 

include("./matrix/test_matrix.jl")
include("./matrix/test_rf.jl")
include("./matrix/test_nc.jl")

include("./gestalt/test_props.jl")
include("./gestalt/test_modKern.jl")

include("./mods/test_mods.jl")

#test_model()

