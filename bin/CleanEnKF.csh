#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# Setup environment
# =================
source config/tools.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/observations.csh
source config/auto/enkf.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADirs[1]
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# ================================================================================================

# Remove obs-database output files
# ================================
if ("$retainObsFeedback" != True) then
  set member = 1
  while ( $member <= ${nMembers} )
    set memDir = `${memberDir} $nMembers $member`
    rm ${self_WorkDir}/${OutDBDir}${memDir}/${obsPrefix}*.h5
    rm ${self_WorkDir}/${OutDBDir}${memDir}/${geoPrefix}*.nc4
    rm ${self_WorkDir}/${OutDBDir}${memDir}/${diagPrefix}*.nc4
    @ member++
  end
endif

# Remove netcdf lock files
rm *.nc*.lock

date

exit 0
