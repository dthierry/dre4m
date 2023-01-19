# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################

module raids
  include("./matrix/mat_struct.jl")
  include("./gestalt/props.jl")
  include("./gestalt/modKern.jl")
  include("./coef/coef_custom.jl")
  include("./mods/model.jl")
  include("./post/postprocess2.jl")
  version = VersionNumber(0, 4, 6)
  @info "RAIDS $(version) by DT@2022"
end
