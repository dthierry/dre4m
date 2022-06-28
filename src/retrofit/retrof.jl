# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  Liosense.
#############################################################################

struct retrofForm
  # capital cost
  rCap::Function
  # variable cost
  rVar::Function
  # fixed cost
  rFix::Function
  # heat rate
  rHtr::Function
  # carbon factor
  rCof::Function
  # fuel cost
  rFuel::Function
end



