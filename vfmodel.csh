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
  set self_StateDir = $inStateDirsArg[$ArgMember]
else
  set self_WorkDir = $WorkDirsArg
  set self_StateDir = $inStateDirsArg
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
setenv self_StatePrefix inStatePrefixArg

echo "WorkDir = ${self_WorkDir}"

#cd ${self_WorkDir}

module load python/3.7.5

#
# collect model-space diagnostic statistics into DB files:
# ========================================================
mkdir -p ${self_WorkDir}/diagnostic_stats/model
cd ${self_WorkDir}/diagnostic_stats/model

set other = $self_StateDir
set bgFileOther = ${other}/${self_StatePrefix}.$fileDate.nc
ln -sf ${bgFileOther} ../restart.$fileDate.nc

ln -fs ${pyModelDir}/*.py ./

foreach mainScript (writediag_modelspace writediagstats_modelspace)
  ln -fs ${pyModelDir}/${mainScript}.py ./

  set success = 1
  while ( $success != 0 )
    mv log.$mainScript log.${mainScript}_LAST
    python ${mainScript}.py "${thisValidDate}" >& log.$mainScript
    set success = $?
    if ( $success != 0 ) then
      source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh
      sleep 3
    endif
  end
end

cd -

date

exit
