#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# Process arguments
# =================
## args

# ArgAppType: str, hofx, variational
set ArgAppType = "$1"

# ArgSubPath: str, /mean, /mem
set ArgSubPath = "$2"

# Setup environment
# =================
source config/environmentNPL.csh
source config/tools.csh
source config/auto/experiment.csh
source config/auto/workflow.csh
source config/auto/naming.csh
source config/auto/observations.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}

# Concatenate the geovals and ydiag feedback files
# =======================================
if ( ${ArgAppType} == "hofx" ) then
  set AppCategory = ${ArgAppType}
  set obsFeedbackDir = ${VerifyObsWorkDir}/${backgroundSubDir}${ArgSubPath}/${thisCycleDate}/${OutDBDir}
else if ( ${ArgAppType} == "variational" ) then
  set AppCategory = "da"
  set obsFeedbackDir = ${DAWorkDir}/${thisCycleDate}/${OutDBDir}
endif

set WorkDir = ${obsFeedbackDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

if ( -e CONCATENATESUCCESS ) then
  echo "$0 (INFO): CONCATENATESUCCESS file already exists, exiting with success"
  echo "$0 (INFO): if regenerating the concatenated files is desired, delete CONCATENATESUCCESS"
  date
  exit 0
endif

set pyScript = "concatenate"
setenv myCommand `$concatenate ${thisCycleDate} ${AppCategory} ${obsFeedbackDir}`
echo "$myCommand"
${myCommand} >& log.${pyScript}

# check if the concatenated files were created successfully
grep "Finished __main__ successfully" log.${pyScript}
if ( $status != 0 ) then
  echo "ERROR in $0 : ${pyScript} failed" > ./FAIL
  exit 1
else
  rm -rf *.nc4
  touch CONCATENATESUCCESS
endif

date

exit 0
