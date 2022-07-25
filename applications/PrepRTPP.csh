#!/bin/csh -f

date

# Setup environment
# =================
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# remove static work directory if it already exists
set self_WorkDir = $CyclingRTPPDir
if ( -d $self_WorkDir ) then
  rm -r $self_WorkDir
endif

exit 0
