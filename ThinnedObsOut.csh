#!/bin/csh -f
# Remove observations after applying the Gaussian thinning QC during the HofX application

date

# Setup environment
# =================
source config/model.csh
source config/experiment.csh
source config/builds.csh
source config/applications/hofx.csh
source config/tools.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = ${thisCycleDate}

source ./getCycleVars.csh

set ccyymmdd = `echo ${thisValidDate} | cut -c 1-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`

# work directory
set WorkDir = ${VerifyQCDirs}/dbOut
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================
set mainScript="createNewIODAv2"
set observationsList = ($observationsToThinning)

set success = 1
while ( $success != 0 )

  mv log.${mainScript} log.${mainScript}_LAST
  echo "$create_newIODAv2_afterThinning -d ${thisValidDate} -o "${observationsList}" -w ${WorkDir}" | tee ./myCommand
  $create_newIODAv2_afterThinning -d ${thisValidDate} -o "${observationsList}" -w ${WorkDir} >& log.${mainScript}
  set success = $?
end

grep "Finished __main__ successfully" log.${mainScript}
if ( $status != 0 ) then
  echo "ERROR in $0 : ${mainScript} failed" > ./FAIL
  exit 1
endif

date

exit 0
