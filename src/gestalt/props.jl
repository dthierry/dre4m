################################################################################
#                    Copyright 2022, UChicago LLC. Argonne                     #
#       This Source Code form is subject to the terms of the MIT license.      #
################################################################################
# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80 tw=80

import Dates

mutable struct prJrnl
  initT::Dates.DateTime
  finalT::Dates.DateTime
  fname::String
  caller::String
  count::Int32
  tag::String
  function prJrnl()
    it = Dates.now()
    ft = Dates.now()
    f = "UNASSIGNED"
    new(it, ft, f, f, 0, "_")
  end
end

@enum jrnlMode j_start j_log_f j_query

function jrnlst!(pr::prJrnl, jMode::jrnlMode)
  fname = pr.fname
  tag = pr.tag
  if jMode == j_start
    @info "Log start."
    initialTime = Dates.now()  # to log the results, I guess
    pr.initT = initialTime
    fname = Dates.format(initialTime, "eyymmdd_HH_MM_SS")
    @info("Started\t$(initialTime)\n")
    @info("Out files:\t$(fname)\n")
    mkdir(fname*tag)
    fname = "./"*fname*tag*"/"*fname*tag
    pr.fname = fname
    refFile = pr.caller
    run(pipeline(`echo $(refFile)`,
        stdout=fname*"_$(pr.count).out"))
    run(pipeline(`cat $(refFile)`, 
        stdout=fname*"_$(pr.count).out", append=true))
    @info "Caller $(refFile)"
  elseif jMode == j_log_f
    pr.finalT = Dates.now()
    @info "Logged @ $(pr.finalT - pr.initT)"
    refFile = pr.caller
    run(pipeline(`echo $(refFile)`,
        stdout=fname*"_$(pr.count).out"))
    run(pipeline(`cat $(refFile)`, 
        stdout=fname*"_$(pr.count).out", append=true))
    @info "Caller $(refFile)"
  end
  if jMode == j_query
    pr.finalT = Dates.now()
    @info "Logged @ $(pr.finalT - pr.initT)"
  else 
    pr.count += 1
  end
end

