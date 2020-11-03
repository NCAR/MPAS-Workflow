#!/bin/csh -f

source ./control.csh
set self_WorkDirs = wrapWorkDirsArg
set self_cylcTaskType = cylcTaskTypeArg
set self_inStateDirs = wrapStateDirsArg
set self_inStatePrefix = wrapStatePrefixArg
set self_StateType = wrapStateTypeArg
set self_AppName = wrapAppNameArg
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
    -e 's@AppNameArg@'${self_AppName}'@' \
    -e 's@AppTypeArg@wrapAppTypeArg@' \
    ${myWrapper}.csh > ${WrapperScript}
chmod 744 ${WrapperScript}

set JobScript=${mainScriptDir}/${self_cylcTaskType}.csh
sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
    -e 's@inStateDirsArg@'${self_inStateDirs}'@' \
    -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
    AppScriptNameArg.csh > ${JobScript}
chmod 744 ${JobScript}

if ( "$self_AppName" =~ *"eda"* ) then
  #NOTE: verification not set up for multiple states yet
  set VFOBSScript=None
  set VFMODELScript=None
else
  set VFObsScript=${mainScriptDir}/VerifyObs${self_StateType}.csh
  sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
      -e 's@nOuterArg@'${self_nOuter}'@' \
      -e 's@jediAppNameArg@wrapjediAppNameArg@' \
      vfobs.csh > ${VFObsScript}
  chmod 744 ${VFObsScript}

  set VFModelScript=${mainScriptDir}/VerifyModel${self_StateType}.csh
  sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
      -e 's@inStateDirsArg@'${self_inStateDirs}'@' \
      -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
      vfmodel.csh > ${VFModelScript}
  chmod 744 ${VFModelScript}
endif

