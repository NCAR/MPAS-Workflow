#!/bin/csh -f

date

# Setup environment
# =================
source config/experiment.csh
source config/applications/rtpp.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingRTPPDir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# ================================================================================================

# Remove original analyses before RTPP
# ====================================
if ("${retainOriginalAnalyses}" == False) then
  rm -r ${anDir}BeforeRTPP
endif

date

exit 0
