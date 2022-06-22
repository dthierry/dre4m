import Dates

mutable struct prop
  initT::Dates.DateTime
end

@enum jrnlMode j_start j_step j_finish

function jrnlst(jMode::jrnlMode)
  if jMode == j_start
    @info "log in some data"
    initialTime = Dates.now()  # to log the results, I guess
    fname0 = Dates.format(initialTime, "eyymmdd-HHMMSS")
    fname = fname0  # copy name
    @info("Started\t$(initialTime)\n")
    @info("Out files:\t$(fname)\n")
    mkdir(fname)
    fname = "./"*fname*"/"*fname
    run(pipeline(`echo $(@__FILE__)`, stdout=fname*"_.out"))
    run(pipeline(`cat $(@__FILE__)`, stdout=fname*"_.out", append=true))
      elseif jMode == j_step
    @info "log in some step info"
  else
    @info "done"
  end
end

