#!/bin/csh -f
# Get GFS analysis (0-h forecast) for cold start initial conditions

# Process arguments
# =================
## args
# ArgMesh: str, mesh name, one of allMeshesJinja
set ArgMesh = "$1"

date

# Setup environment
# =================
source config/builds.csh
source config/experiment.csh
source config/externalanalyses.csh
source config/model.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

if ("$ArgMeshName" == "$outerMesh") then
  set WorkDir = ${ExternalAnalysisDirOuter}
  set filePrefix = $externalanalyses__filePrefixOuter
  set externalDirectory = `echo "$externalanalyses__externalDirectoryOuter" \
    | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
    `
else if ("$ArgMeshName" == "$innerMesh") then
  set WorkDir = ${ExternalAnalysisDirInner}
  set filePrefix = $externalanalyses__filePrefixInner
  set externalDirectory = `echo "$externalanalyses__externalDirectoryInner" \
    | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
    `
else if ("$ArgMeshName" == "$ensembleMesh") then
  set WorkDir = ${ExternalAnalysisDirEnsemble}
  set filePrefix = $externalanalyses__filePrefixEnsemble
  set externalDirectory = `echo "$externalanalyses__externalDirectoryEnsemble" \
    | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
    `
else
  echo "$0 (ERROR): invalid ArgMeshName ($ArgMeshName)"
  exit 1
endif

echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

ln -sfv $externalDirectory/$filePrefix.$thisMPASFileDate.nc ./

date

exit 0
