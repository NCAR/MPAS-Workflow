#!/bin/csh

date

#
# Setup environment:
# =============================================
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

set self_WorkDir = $CyclingDADir

echo "WorkDir = ${self_WorkDir}"

cd ${self_WorkDir}

# Remove obs-database output files
# ================================
#set member = 1
#while ( $member <= ${nEnsDAMembers} )
#  set memDir = `${memberDir} $DAType $member`
#  rm ${self_WorkDir}/${OutDBDir}${memDir}/${obsPrefix}*.nc4
#  rm ${self_WorkDir}/${OutDBDir}${memDir}/${geoPrefix}*.nc4
#  rm ${self_WorkDir}/${OutDBDir}${memDir}/${diagPrefix}*.nc4
#  @ member++
#end

date

exit 0
