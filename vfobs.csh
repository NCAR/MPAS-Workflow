#!/bin/csh

date

set ArgMember = "$1"
set ArgDT = "$2"
set ArgStateType = "$3"
set ArgNMembers = "$4"

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

module load python/3.7.5

#
# collect obs-space diagnostic statistics into DB files:
# ======================================================
mkdir -p ${self_WorkDir}/diagnostic_stats/obs
cd ${self_WorkDir}/diagnostic_stats/obs

set mainScript="writediagstats_obsspace"
ln -fs ${pyObsDir}/*.py ./
ln -fs ${pyObsDir}/${mainScript}.py ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

set success = 1
while ( $success != 0 )
  mv log.${mainScript} log.${mainScript}_LAST
  setenv baseCommand "python ${mainScript}.py -n ${NUMPROC} -p ${self_WorkDir}/${OutDBDir} -o ${obsPrefix} -g ${geoPrefix} -d ${diagPrefix}"

  if ($ArgMember == 0 && $ArgNMembers > 0) then
    echo "${baseCommand} -m $ArgNMembers -e ${VerificationWorkDir}/${bgDir}${oopsMemFmt}/${thisCycleDate}/${OutDBDir}"
    ${baseCommand} -m $ArgNMembers -e "${VerificationWorkDir}/${bgDir}${oopsMemFmt}/${thisCycleDate}/${OutDBDir}" >& log.${mainScript}
  else
    echo "${baseCommand}"
    ${baseCommand} >& log.${mainScript}
  endif

  set success = $?

  if ( $success != 0 ) then
    source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh
    sleep 3
  endif
end
cd -

date

exit
