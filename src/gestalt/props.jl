# vim: tabstop=2 shiftwidth=2 expandtab colorcolumn=80
#############################################################################
#  Copyright 2022, David Thierry, and contributors
#  This Source Code Form is subject to the terms of the MIT
#  License.
#############################################################################
import Dates

mutable struct prJrnl
  initT::Dates.DateTime
  finalT::Dates.DateTime
  fname::String
  caller::String
  count::Int32
  function prJrnl()
    it = Dates.now()
    ft = Dates.now()
    f = "UNASSIGNED"
    new(it, ft, f, f, 0)
  end
end

@enum jrnlMode j_start j_log_f j_finish

function jrnlst!(pr::prJrnl, jMode::jrnlMode)
  fname = pr.fname
  if jMode == j_start
    @info "log in some data"
    initialTime = Dates.now()  # to log the results, I guess
    pr.initT = initialTime
    fname = Dates.format(initialTime, "eyymmdd-HHMMSS")
    @info("Started\t$(initialTime)\n")
    @info("Out files:\t$(fname)\n")
    mkdir(fname)
    fname = "./"*fname*"/"*fname
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
  pr.count += 1
end

