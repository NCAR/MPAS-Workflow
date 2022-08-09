#!/bin/csh -f
# Get GFS analysis (0-h forecast) for cold start initial conditions

# Process arguments
# =================
## args
# ArgMesh: str, mesh name, one of model.meshes
set ArgMesh = "$1"

date

# Setup environment
# =================
source config/auto/build.csh
source config/auto/externalanalyses.csh
source config/auto/model.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

if ("$ArgMesh" == "$outerMesh") then
  set WorkDir = ${ExternalAnalysisDirOuter}
  set filePrefix = $externalanalyses__filePrefixOuter
  set directory = `echo "$externalanalyses__directoryOuter" \
    | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
    `
else if ("$ArgMesh" == "$innerMesh") then
  set WorkDir = ${ExternalAnalysisDirInner}
  set filePrefix = $externalanalyses__filePrefixInner
  set directory = `echo "$externalanalyses__directoryInner" \
    | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
    `
else if ("$ArgMesh" == "$ensembleMesh") then
  set WorkDir = ${ExternalAnalysisDirEnsemble}
  set filePrefix = $externalanalyses__filePrefixEnsemble
  set directory = `echo "$externalanalyses__directoryEnsemble" \
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

ln -sfv $directory/$filePrefix.$thisMPASFileDate.nc ./

date

exit 0