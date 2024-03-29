# Copyright (C) 2023, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: DRE4M: Decarbonization Roadmapping and Energy, Environmental, 
# Economic, and Equity Analysis Model
# By: Argonne National Laboratory
# BSD OPEN SOURCE LICENSE

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the names of its contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission.

# ******************************************************************************
# DISCLAIMER
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# ******************************************************************************

using XLSX
using DataFrames

# aeotab8 : net generation by fuel type
f8 = "./data/aeotab_8.xlsx"
# aeotab9 : net summer capacity
f9 = "./data/aeotab_9.xlsx"

f8sSheet = "ref2021.1130a"
#headG = XLSX.readdata(f8, f8sSheet*"!C13:AG13")
dfG1 = DataFrame(XLSX.readtable(f8, "ref2021.1130a", "C:AG"; 
                               first_row=19, 
                               header=false, 
                               stop_in_empty_row=true)...)
dfG2 = DataFrame(XLSX.readtable(f8, "ref2021.1130a", "C:AG"; 
                               first_row=28, 
                               header=false, 
                               stop_in_empty_row=true)...)


colnames = names(dfG1)
dfG1[!, :id] = 1:size(dfG1, 1)
dfl = stack(dfG1, colnames)
dfG1 = unstack(dfl, :variable, :id, :value)

colnames = names(dfG2)
dfG2[!, :id] = 1:size(dfG2, 1)
dfl = stack(dfG2, colnames)
dfG2 = unstack(dfl, :variable, :id, :value)

actGen = DataFrame(year=2020:2050)
#for i in 2:4
#    global actGen[:, string(i)] = dfG1[:, i] + dfG2[:, i]
#end
actGen[:, :PC] = dfG1[:, 2] + dfG2[:, 2]
actGen[:, :NG] = dfG1[:, 4] + dfG2[:, 4]
actGen[:, :NUC] = dfG1[:, 5]
###

###
f9sSheet = "ref2021.1130a"
dfC1 = DataFrame(XLSX.readtable(f9, f9sSheet, "C:AG";
                 first_row=17,
                 header=false,
                 stop_in_empty_row=true)...)

dfC2 = DataFrame(XLSX.readtable(f9, f9sSheet, "C:AG";
                                first_row=29,
                                header=false,
                                stop_in_empty_row=true) ...)



colnames = names(dfC1)
dfC1[!, :id] = 1:size(dfC1, 1)
dfl = stack(dfC1, colnames)
dfC1 = unstack(dfl, :variable, :id, :value)

colnames = names(dfC2)
dfC2[!, :id] = 1:size(dfC2, 1)
dfl = stack(dfC2, colnames)
dfC2 = unstack(dfl, :variable, :id, :value)

actCap = DataFrame(year=2020:2050)
actCap[:, :PC] = (dfC1[:, 2] + dfC2[:, 2]).*(365*24/1000)
actCap[:, :CC] = (dfC1[:, 4] + dfC2[:, 4]).*(365*24/1000)
actCap[:, :NUC] = (dfC1[:, 6]).*(365*24/1000)


actCF = DataFrame(year=2020:2050)

actCF[:, :PC] = actGen[:,:PC]./actCap[:,:PC] # coal
actCF[:, :CC] = actGen[:,:NG]./actCap[:,:CC] # cc
actCF[:, :NUC] = actGen[:,:NUC]./actCap[:,:NUC] # nuclear

XLSX.writetable("miss_cap.xlsx", actCF)

