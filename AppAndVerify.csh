#!/bin/csh -f

source ./control.csh
set self_WorkDirs = wrapWorkDirsArg
set self_cylcTaskType = cylcTaskTypeArg
set self_inStateDirs = wrapStateDirsArg
set self_inStatePrefix = wrapStatePrefixArg
set self_DAType = wrapDATypeArg

echo "Making multiple job scripts for wrapStateTypeArg state"

set myWrapper = jediPrep
set WrapperScript=${MAIN_SCRIPT_DIR}/${myWrapper}${self_cylcTaskType}.csh
sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
    -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
    -e 's@WindowHRArg@wrapWindowHRArg@' \
    -e 's@ObsListArg@OMMObsList@' \
    -e 's@VARBCTableArg@wrapVARBCTableArg@' \
    -e 's@DATypeArg@'${self_DAType}'@' \
    -e 's@DAModeArg@wrapDAModeArg@' \
    ${myWrapper}.csh > ${WrapperScript}
chmod 744 ${WrapperScript}

set JobScript=${MAIN_SCRIPT_DIR}/${self_cylcTaskType}.csh
sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
    -e 's@inStateDirsArg@'${self_inStateDirs}'@' \
    -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
    -e 's@DATypeArg@'${self_DAType}'@' \
    -e 's@ExpNameArg@'${ExpName}'@' \
    -e 's@AccountNumberArg@wrapAccountNumberArg@' \
    -e 's@QueueNameArg@wrapQueueNameArg@' \
    -e 's@NNODEArg@wrapNNODEArg@' \
    -e 's@NPEArg@wrapNPEArg@g' \
    AppNameArg.csh > ${JobScript}
chmod 744 ${JobScript}

if ( "$self_DAType" =~ *"eda"* ) then
  #NOTE: verification not set up for multiple states yet
  set VFOBSScript=None
  set VFMODELScript=None
else
  set VFObsScript=${MAIN_SCRIPT_DIR}/VerifyObswrapStateTypeArg.csh
  sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
      -e 's@AccountNumberArg@'${VFAccountNumber}'@' \
      -e 's@QueueNameArg@'${VFQueueName}'@' \
      -e 's@ExpNameArg@'${ExpName}'@' \
      vfobs_job.csh > ${VFObsScript}
  chmod 744 ${VFObsScript}

  set VFModelScript=${MAIN_SCRIPT_DIR}/VerifyModelwrapStateTypeArg.csh
  sed -e 's@WorkDirsArg@'${self_WorkDirs}'@' \
      -e 's@inStateDirsArg@'${self_inStateDirs}'@' \
      -e 's@inStatePrefixArg@'${self_inStatePrefix}'@' \
      -e 's@AccountNumberArg@'${VFAccountNumber}'@' \
      -e 's@QueueNameArg@'${VFQueueName}'@' \
      -e 's@ExpNameArg@'${ExpName}'@' \
      vfmodel_job.csh > ${VFModelScript}
  chmod 744 ${VFModelScript}
endif

