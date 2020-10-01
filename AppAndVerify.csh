#!/bin/csh -f

source ./control.csh
set self_WorkDirs = wrapWorkDirsArg
set self_cylcTaskType = cylcTaskTypeArg
set self_inStateDirs = wrapStateDirsArg
set self_inStatePrefix = wrapStatePrefixArg
set self_StateType = wrapStateTypeArg
set self_DAType = wrapDATypeArg
set self_nOuter = wrapnOuterArg

set myWrapper = jediPrep
foreach name ( \
  ${myWrapper}${self_cylcTaskType} \
  ${self_cylcTaskType} \
  VerifyObs${self_StateType} \
  VerifyModel${self_StateType} \
)
  echo "Making $name job script for ${self_StateType} state"
end
set WrapperScript=${mainScriptDir}/${myWrapper}${self_cylcTaskType}.csh
sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
    -e 's@WindowHRArg@wrapWindowHRArg@' \
    -e 's@ObsListArg@wrapObsListArg@' \
    -e 's@VARBCTableArg@wrapVARBCTableArg@' \
    -e 's@DATypeArg@'${self_DAType}'@' \
    -e 's@DAModeArg@wrapDAModeArg@' \
    ${myWrapper}.csh > ${WrapperScript}
chmod 744 ${WrapperScript}

set JobScript=${mainScriptDir}/${self_cylcTaskType}.csh
sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
    -e 's@inStateDirsArg@'${self_inStateDirs}'@' \
    -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
    AppNameArg.csh > ${JobScript}
chmod 744 ${JobScript}

if ( "$self_DAType" =~ *"eda"* ) then
  #NOTE: verification not set up for multiple states yet
  set VFOBSScript=None
  set VFMODELScript=None
else
  set VFObsScript=${mainScriptDir}/VerifyObs${self_StateType}.csh
  sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
      -e 's@nOuterArg@'${self_nOuter}'@' \
      vfobs.csh > ${VFObsScript}
  chmod 744 ${VFObsScript}

  set VFModelScript=${mainScriptDir}/VerifyModel${self_StateType}.csh
  sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
      -e 's@inStateDirsArg@'${self_inStateDirs}'@' \
      -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
      vfmodel.csh > ${VFModelScript}
  chmod 744 ${VFModelScript}
endif

