#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# Process arguments
# =================
## args
# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgWorkDir: str, where to run
set ArgWorkDir = "$2"


## arg checks
set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

# Setup environment
# =================
source config/tools.csh
source config/auto/hofx.csh
source config/auto/observations.csh
source config/auto/experiment.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./bin/getCycleVars.csh

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
cd ${WorkDir}

# ================================================================================================

# Remove unnecessary model state files
# ====================================
rm ${WorkDir}/${backgroundSubDir}/${BGFilePrefix}.$thisMPASFileDate.nc

# Remove obs-database output files
# ================================
if ("$retainObsFeedback" != True) then
  rm ${WorkDir}/${OutDBDir}/${obsPrefix}*.h5
  rm ${WorkDir}/${OutDBDir}/${geoPrefix}*.nc4
  rm ${WorkDir}/${OutDBDir}/${diagPrefix}*.nc4
endif

date

exit 0
