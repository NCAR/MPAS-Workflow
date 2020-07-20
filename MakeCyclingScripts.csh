#!/bin/csh -f
source ./control.csh
set AppAndVerify = AppAndVerify

echo "==============================================================\n"
echo "Making cycling scripts for experiment: ${ExpName}\n"
echo "==============================================================\n"

rm -rf ${mainScriptDir}
mkdir -p ${mainScriptDir}
set cyclingParts = ( \
  control.csh \
  getCycleVars.csh \
  tools \
  config \
  ${MPAS_RES} \
)
foreach part ($cyclingParts)
  cp -rP $part ${mainScriptDir}/
end

## First cycle "forecast" established offline
# TODO: make FirstCycleDate behavior part of CyclingFC or seperate application
#       instead of work-flow initialization? Could use zero-length fc or new fcinit
set thisCycleDate = $FirstCycleDate
set thisValidDate = $thisCycleDate
source getCycleVars.csh
if ( ${thisCycleDate} == ${FirstCycleDate} ) then
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
#TODO: enable mean state diagnostics; only works for deterministic DA
set WorkDir = ${CyclingDADir}
set cylcTaskType = CyclingDA
set WrapperScript=${mainScriptDir}/${AppAndVerify}DA.csh
sed -e 's@wrapWorkDirsArg@CyclingDADir@' \
    -e 's@AppNameArg@da@' \
    -e 's@cylcTaskTypeArg@'${cylcTaskType}'@' \
    -e 's@wrapStateDirsArg@prevCyclingFCDirs@' \
    -e 's@wrapStatePrefixArg@'${bgStatePrefix}'@' \
    -e 's@wrapStateTypeArg@DA@' \
    -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
    -e 's@wrapWindowHRArg@'${CYWindowHR}'@' \
    -e 's@wrapDATypeArg@'${DAType}'@g' \
    -e 's@wrapDAModeArg@da@g' \
    -e 's@wrapObsListArg@DAObsList@' \
    ${AppAndVerify}.csh > ${WrapperScript}
chmod 744 ${WrapperScript}
${WrapperScript}
rm ${WrapperScript}


#------- CyclingFC ---------
echo "Making CyclingFC job script"
set JobScript=${mainScriptDir}/CyclingFC.csh
sed -e 's@WorkDirsArg@CyclingFCDirs@' \
    -e 's@fcLengthHRArg@'${CYWindowHR}'@' \
    -e 's@fcIntervalHRArg@'${CYWindowHR}'@' \
    fc.csh > ${JobScript}
chmod 744 ${JobScript}


#------- ExtendedFC ---------
echo "Making ExtendedFC job script"
set JobScript=${mainScriptDir}/ExtendedFC.csh
sed -e 's@WorkDirsArg@ExtendedFCDirs@' \
    -e 's@fcLengthHRArg@'${ExtendedFCWindowHR}'@' \
    -e 's@fcIntervalHRArg@'${ExtendedFC_DT_HR}'@' \
    fc.csh > ${JobScript}
chmod 744 ${JobScript}


#------- CalcOM{{state}}, VerifyObs{{state}}, VerifyModel{{state}} ---------
foreach state (AN BG FC)
  if (${state} == AN) then
    set child_ARGS = (CyclingDAOutDirs ${ANFilePrefix} ${CYWindowHR})
  else if (${state} == BG) then
    set child_ARGS = (prevCyclingFCDirs ${FCFilePrefix} ${CYWindowHR})
  else if (${state} == FC) then
    set child_ARGS = (ExtendedFCDirs ${FCFilePrefix} ${DAVFWindowHR})
  endif
  set cylcTaskType = CalcOM${state}
  set WrapperScript=${mainScriptDir}/${AppAndVerify}${state}.csh
  sed -e 's@wrapWorkDirsArg@Verify'${state}'Dirs@' \
      -e 's@AppNameArg@'${omm}'@' \
      -e 's@cylcTaskTypeArg@'${cylcTaskType}'@' \
      -e 's@wrapStateDirsArg@'$child_ARGS[1]'@' \
      -e 's@wrapStatePrefixArg@'$child_ARGS[2]'@' \
      -e 's@wrapStateTypeArg@'${state}'@' \
      -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
      -e 's@wrapWindowHRArg@'$child_ARGS[3]'@' \
      -e 's@wrapDATypeArg@'${omm}'@g' \
      -e 's@wrapDAModeArg@'${omm}'@g' \
      -e 's@wrapObsListArg@OMMObsList@' \
      ${AppAndVerify}.csh > ${WrapperScript}
  chmod 744 ${WrapperScript}
  ${WrapperScript}
  rm ${WrapperScript}
end

exit 0
