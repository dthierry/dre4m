# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80 tw=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
#
import Clp
Clp.Clp_Version()

using mid_s
using JuMP
include("../src/bark/thinghys.jl")

function main()
  pr = mid_s.prJrnl()
  jrnl = mid_s.j_start
  pr.caller = @__FILE__
  mid_s.jrnlst!(pr, jrnl)
  file = "/Users/dthierry/Projects/mid-s/data/cap_mw.xlsx"
  T = 2050-2015
  gf = mid_s.gridForm(I)
  # Set arbitrary (new) tech for subprocess i
  for i in 1:I
    gf.kinds_x[i] = kinds_x[i]
    gf.kinds_z[i] = kinds_z[i]
    gf.xDelay[i-1] = 0 # xDelay[i-1]
  end
  gf.co2Based[0] = true  # PC
  gf.co2Based[1] = true  # NGCT
  gf.co2Based[2] = true  # NGCC
  gf.co2Based[3] = true  # P
  gf.co2Based[4] = true  # B

  gf.fuelBased[0] = true  # PC
  gf.fuelBased[1] = true  # NGCT
  gf.fuelBased[2] = true  # NGCC
  gf.fuelBased[3] = true  # P
  gf.fuelBased[4] = true  # B
  gf.fuelBased[5] = true  # N
  # set retrofit form
  ta = mid_s.timeAttr(file)
  ca = mid_s.costAttr(file)
  ia = mid_s.invrAttr(file)
  #
  sl = ia.servLife
  si = [0.01 for i in 1:I]
  si[1] = 0.1 # ten percent for coal
  # twenty percent service life increase
  # setup sets
  mS = mid_s.modSets(T, I, gf, sl, si)
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  # setup retrofitform
  rf = mid_s.retrofForm(rfCaGrd,
                        rfOnMgrd, 
                        rfOnMgrd, 
                        rfHtrGrd, 
                        rfCoGrd, 
                        rfFuGrd)
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  mD = mid_s.modData(gf, ta, ca, ia, rf)
  mid_s.preProcCoef!(mD)
  #for j in 1:size(mD.ta.cFac)[2]
  #  mD.ta.cFac[8, j] = 0.99
  #end

  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  mod = mid_s.genModel(mS, mD, pr) 
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  mid_s.genObj!(mod, mS, mD)
  ###$$$$  ###$$$$  ###$$$$  ###$$$$
  # Some additional constraints
  mid_s.fixDelayed0!(mod, mS, mD)
  mid_s.gridConWind!(mod, mS, 7, Dict(8=>0.25, 9=>0.25, 10=>0.03))
  mid_s.gridConUppahBound!(mod, mS)
  mid_s.gridConBudget!(mod, mS)
  jrnl = mid_s.j_query
  mid_s.jrnlst!(pr, jrnl)
  set_optimizer(mod, Clp.Optimizer)
  optimize!(mod)
  mid_s.jrnlst!(pr, jrnl)
  mid_s.writeRes(mod, mS, mD, pr)
  mid_s.jrnlst!(pr, jrnl)
  return mod, mS, mD, pr
end


if abspath(PROGRAM_FILE) == @__FILE__
  m = main()
end
