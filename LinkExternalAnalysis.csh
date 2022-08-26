#!/bin/csh -f
# Get GFS analysis (0-h forecast) for cold start initial conditions

# Process arguments
# =================
## args
# ArgMesh: str, mesh name, one of allMeshesJinja
set ArgMesh = "$1"

# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$2"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/builds.csh
source config/experiment.csh
source config/externalanalyses.csh
source config/model.csh
source config/tools.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

if ("$ArgMesh" == "$outerMesh") then
  set WorkDir = ${ExternalAnalysisDirOuter}
  set filePrefix = $externalanalyses__filePrefixOuter
  set externalDirectory = `echo "$externalanalyses__externalDirectoryOuter" \
    | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
    `
else if ("$ArgMesh" == "$innerMesh") then
  set WorkDir = ${ExternalAnalysisDirInner}
  set filePrefix = $externalanalyses__filePrefixInner
  set externalDirectory = `echo "$externalanalyses__externalDirectoryInner" \
    | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
    `
else if ("$ArgMesh" == "$ensembleMesh") then
  set WorkDir = ${ExternalAnalysisDirEnsemble}
  set filePrefix = $externalanalyses__filePrefixEnsemble
  set externalDirectory = `echo "$externalanalyses__externalDirectoryEnsemble" \
    | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
    `
else
  echo "$0 (ERROR): invalid ArgMesh ($ArgMesh)"
  exit 1
endif

echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

ln -sfv $externalDirectory/$filePrefix.$thisMPASFileDate.nc ./

date

exit 0
