# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################

module mid_s
  include("./bark/bark.jl")
  include("./matrix/mat_struct.jl")
  include("./gestalt/props.jl")
  include("./gestalt/gridForm.jl")
  include("./gestalt/retrof.jl")
  include("./gestalt/modKern.jl")
  include("./pre/preprocess.jl")
  include("./coef/coef_custom.jl")
  include("./mods/m4-3_modular.jl")
  include("./post/postprocess.jl")
end
