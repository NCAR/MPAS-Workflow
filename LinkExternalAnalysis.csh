#!/bin/csh -f
# Get GFS analysis (0-h forecast) for cold start initial conditions

date

# Setup environment
# =================
source config/builds.csh
source config/experiment.csh
source config/externalanalyses.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set WorkDir = ${ExternalAnalysisDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================


set externalDirectory = `echo "$externalanalyses__externalDirectory" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `

ln -sfv $externalDirectory/$externalanalyses__filePrefix.$thisMPASFileDate.nc ./

date

exit 0
