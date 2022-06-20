#####
# PREPROCESSING OF (SOME) COEFFICIENT MATRICES
#####
function preProcCoef(c::coef)
  #: CapC $/kW -> M$/GW
  #: fixC $/kW -> M$/GW
  #: varC $/MWh -> M$/GWh
  c.varC.*=(1e3/1e6)
  #: decomC[=] $/MW -> M$/GW
  c.decomC.*=(1e3/1e6)
  #: elecsales[=] cent/kWh -> M$/GWh
  c.elecSaleC.*=(1e6/(100.*1e6))
  #: heatRw[=] BTU/kWh -> MMBTU/GWh
  c.heatRw.*=(1e6/1e6)
  #: heatRx[=] BTU/kWh -> MMBTU/GWh
  c.heatRx.*=(1e6/1e6)
end

function preProcAttr(a:attr)
  :q
end

#
#: Note, this block should be done in functions or something else

#: Capacity matrix
# (MW) --> (GW)
cap_mat = cap_mat./1e3

# ($/MMBTU) --> (M$/MMBTU)
fuel_mat = fuel_mat./1e6 # M$/MMBTU

# (BTU/kWh) --> (MMBTU/GWh) Same thing!
# heatRateInputMatrix = heatRateInputMatrix # to (MMBTU/GWh)
# (BTU/kWh) --> (MMBTU/GWh) Same thing!
# heatRateInputMatrixNew = heatRateInputMatrixNew # to (MMBTU/GWh)

# ($/MWh) --> (M$/GWh)
# util_techcost = util_techcost.*(1e3/1e6)
loan_period = 20

# cent/kwh = 1/100 * 1000 $/MWh
# (dollar/MWh) --> (M$/GWh)
util_revenues = util_revenues.*((1000/100)* 1e3/1e6)

# ($/MWh) --> (M$/GWh)
util_decom = util_decom.*(1e3/1e6)

# (kgCO2/MMBTU)--> (tCO2/MMBTU)
emissionRate = emissionRate./1e3

# ($/kW-yr) --> (M$/GW-yr) Same thing!
# foam_mat = foam_mat 
# kWyr --> 24*365*kWh
# kW <-- kWyr/(1 year)
foam_mat = foam_mat.*1.

# ($/MWh) --> (M$/GWh)
voam_mat = voam_mat.*(1e3/1e6) 

# ($/kW) --> (M$/GW) Same thing!
# kWh = kW * hours 
# cc_mat = cc_mat #: Checked ✅ 

# (MWh) --> (GWh)
d_mat = d_mat./1e3


