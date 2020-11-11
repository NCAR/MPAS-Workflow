#!/bin/csh

date

set ArgMember = "$1"
set ArgDT = "$2"
set ArgStateType = "$3"

#
# Setup environment:
# =============================================
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

set test = `echo $ArgMember | grep '^[0-9]*$'`
set isInt = (! $status)
if ( $isInt && "$ArgMember" != "0") then
  set self_WorkDir = $WorkDirsArg[$ArgMember]
else
  set self_WorkDir = $WorkDirsArg
endif
set test = `echo $ArgDT | grep '^[0-9]*$'`
set isInt = (! $status)
if ( ! $isInt) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif
if ($ArgDT > 0 || "$ArgStateType" =~ *"FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif

echo "WorkDir = ${self_WorkDir}"

cd ${self_WorkDir}

# Remove unnecessary model state files
# ====================================
rm ${self_WorkDir}/${bgDir}/${BGFilePrefix}.$fileDate.nc
rm ${self_WorkDir}/${anDir}/${ANFilePrefix}.$fileDate.nc

# Remove obs-database output files
# ================================
rm ${self_WorkDir}/${OutDBDir}/${obsPrefix}*.nc4
rm ${self_WorkDir}/${OutDBDir}/${geoPrefix}*.nc4
rm ${self_WorkDir}/${OutDBDir}/${diagPrefix}*.nc4

date

exit 0
