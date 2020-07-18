#!/bin/csh -f
source ./control.csh
set cycle_Date = $FirstCycleDate
source getCycleDirectories.csh
set AppAndVerify = AppAndVerify

echo "==============================================================\n"
echo "Making cycling scripts for experiment: ${ExpName}\n"
echo "==============================================================\n"

rm -rf ${MAIN_SCRIPT_DIR}
mkdir -p ${MAIN_SCRIPT_DIR}
cp control.csh ${MAIN_SCRIPT_DIR}
cp getCycleDirectories.csh ${MAIN_SCRIPT_DIR}

## First cycle "forecast" established offline
# TODO: make FirstCycleDate behavior part of CyclingFC or seperate application
#       instead of top-level workflow using zero-length fc_job
if ( ${cycle_Date} == ${FirstCycleDate} ) then
  mkdir -p ${CyclingFCWorkDir}
  rm -r ${prevCyclingFCDir}
  set member = 1
  while ( $member <= ${nEnsDAMembers} )
    if ( "$DAType" =~ *"eda"* ) then
      mkdir ${prevCyclingFCDir}
      set InitialFC = "$ensembleICFirstCycle"`${memberDir} ens $member "${fixedEnsMemFmt}"`
    else
      set InitialFC = $deterministicICFirstCycle
    endif
    ln -sf ${InitialFC} $prevCyclingFCDirs[$member]

    @ member++
  end
#TODO: currently RSTFilePrefix and FCFilePrefix must be the same
  setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}
  setenv bgStatePrefix ${RSTFilePrefix}
else
  setenv VARBC_TABLE ${prevCyclingDADir}/${VARBC_ANA}
  setenv bgStatePrefix ${FCFilePrefix}
endif


#------- CyclingDA ---------
#TODO: enable mean state diagnostics; only work for deterministic DA
set WorkDir = ${CyclingDADir}
set cylcTaskType = CyclingDA
set WrapperScript=${MAIN_SCRIPT_DIR}/${AppAndVerify}DA.csh
sed -e 's@wrapWorkDirsArg@CyclingDADir@' \
    -e 's@AppNameArg@da_job@' \
    -e 's@cylcTaskTypeArg@'${cylcTaskType}'@' \
    -e 's@wrapMemberArg@ALL@' \
    -e 's@wrapStateDirsArg@prevCyclingFCDirs@' \
    -e 's@wrapStatePrefixArg@'${bgStatePrefix}'@' \
    -e 's@wrapStateTypeArg@DA@' \
    -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
    -e 's@wrapWindowHRArg@'${CYWindowHR}'@' \
    -e 's@wrapDATypeArg@'${DAType}'@g' \
    -e 's@wrapDAModeArg@da@g' \
    -e 's@wrapAccountNumberArg@'${CYAccountNumber}'@' \
    -e 's@wrapQueueNameArg@'${CYQueueName}'@' \
    -e 's@wrapNNODEArg@'${CyclingDANodes}'@' \
    -e 's@wrapNPEArg@'${CyclingDAPEPerNode}'@g' \
    ${AppAndVerify}.csh > ${WrapperScript}
chmod 744 ${WrapperScript}
${WrapperScript}
rm ${WrapperScript}


#------- CyclingFC ---------
echo "Making CyclingFC job script"
set JobScript=${MAIN_SCRIPT_DIR}/CyclingFC.csh
sed -e 's@WorkDirsArg@CyclingFCDirs@' \
    -e 's@fcLengthHRArg@'${CYWindowHR}'@' \
    -e 's@fcIntervalHRArg@'${CYWindowHR}'@' \
    -e 's@JobMinutesArg@'${CyclingFCJobMinutes}'@' \
    -e 's@AccountNumberArg@'${CYAccountNumber}'@' \
    -e 's@QueueNameArg@'${CYQueueName}'@' \
    -e 's@ExpNameArg@'${ExpName}'@' \
    fc_job.csh > ${JobScript}
chmod 744 ${JobScript}


#------- ExtendedFC ---------
echo "Making ExtendedFC job script"
set JobScript=${MAIN_SCRIPT_DIR}/ExtendedFC.csh
sed -e 's@WorkDirsArg@ExtendedFCDirs@' \
    -e 's@fcIntervalHRArg@'${ExtendedFC_DT_HR}'@' \
    -e 's@JobMinutesArg@'${ExtendedFCJobMinutes}'@' \
    -e 's@AccountNumberArg@'${CYAccountNumber}'@' \
    -e 's@QueueNameArg@'${CYQueueName}'@' \
    -e 's@ExpNameArg@'${ExpName}'@' \
    fc_job.csh > ${JobScript}
chmod 744 ${JobScript}


#------- CalculateOM{{state}}, VerifyObs{{state}}, VerifyModel{{state}} ---------
foreach state (AN BG FC)
  if (${state} == AN) then
    set child_ARGS = (CyclingDAOutDirs ${ANFilePrefix} ${CYWindowHR})
  else if (${state} == BG) then
    set child_ARGS = (CyclingFCDirs ${FCFilePrefix} ${CYWindowHR})
  else if (${state} == FC) then
    set child_ARGS = (ExtendedFCDirs ${FCFilePrefix} ${DAVFWindowHR})
  endif
  set cylcTaskType = CalculateOM${state}
  set WrapperScript=${MAIN_SCRIPT_DIR}/${AppAndVerify}${state}.csh
  sed -e 's@wrapWorkDirsArg@Verify'${state}'Dirs@' \
      -e 's@AppNameArg@'${omm}'_job@' \
      -e 's@cylcTaskTypeArg@'${cylcTaskType}'@' \
      -e 's@wrapStateDirsArg@'$child_ARGS[1]'@' \
      -e 's@wrapStatePrefixArg@'$child_ARGS[2]'@' \
      -e 's@wrapStateTypeArg@'${state}'@' \
      -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
      -e 's@wrapWindowHRArg@'$child_ARGS[3]'@' \
      -e 's@wrapDATypeArg@'${omm}'@g' \
      -e 's@wrapDAModeArg@'${omm}'@g' \
      -e 's@wrapAccountNumberArg@'${VFAccountNumber}'@' \
      -e 's@wrapQueueNameArg@'${VFQueueName}'@' \
      -e 's@wrapNNODEArg@'${OMMNodes}'@' \
      -e 's@wrapNPEArg@'${OMMPEPerNode}'@g' \
      ${AppAndVerify}.csh > ${WrapperScript}
  chmod 744 ${WrapperScript}
  ${WrapperScript}
  rm ${WrapperScript}
end

exit 0
