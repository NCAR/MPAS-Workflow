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

set self_WorkDir = $MeanAnalysisDir
set self_StateDirs = ($CyclingDAOutDirs)
set self_StatePrefix = ${ANFilePrefix}

echo "WorkDir = ${self_WorkDir}"

mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

set memberPrefix = ${self_StatePrefix}.${fileDate}mem
set analysisName = ${self_StatePrefix}.$fileDate.nc
set varianceName = ${self_StatePrefix}.$fileDate.variance.nc

set member = 1
while ( $member <= ${nEnsDAMembers} )
  set appMember = `${memberDir} ens $member "{:03d}"`
# set appMember = printf "%03d" $member`
  ln -sf $self_StateDirs[$member]/${analysisName} ./${memberPrefix}${appMember}
  @ member++
end

if (${nEnsDAMembers} == 1) then
  ## pass-through for mean
  ln -sf $self_StateDirs[1]/${analysisName} ./
else
  ## make copy for mean
  cp $self_StateDirs[1]/${analysisName} ./

  ## make copy for variance
  cp $self_StateDirs[1]/${analysisName} ./${varianceName}

  # ===================
  # ===================
  # Run the executable:
  # ===================
  # ===================
  set arg1 = ${self_WorkDir}
  set arg2 = ${analysisName}
  set arg3 = ${varianceName}
  set arg4 = ${memberPrefix}
  set arg5 = ${nEnsDAMembers}

  ln -sf ${meanStateBuildDir}/${meanStateExe} ./
  mpiexec ./${meanStateExe} "$arg1" "$arg2" "$arg3" "$arg4" "$arg5" >& log

  ##
  ## Check status:
  ## =============================================
  #grep 'CHARACTERISTIC STRING' log
  #if ( $status != 0 ) then
  #  touch ./FAIL
  #  echo "ERROR in $0 : mean state application failed" >> ./FAIL
  #  exit 1
  #endif

  ## massage output as needed...
endif

date

exit 0
