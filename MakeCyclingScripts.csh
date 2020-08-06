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
  MeanAnalysis.csh \
  RTPPInflation.csh \
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
set member = 1
while ( $member <= ${nEnsDAMembers} )
  if ( "$DAType" =~ *"eda"* ) then
    set InitialFC = "$firstEnsFCDir"`${memberDir} ens $member "${firstEnsFCMemFmt}"`
  else
    set InitialFC = $firstDetermFCDir
  endif
  rm -r $prevCyclingFCDirs[$member]
  mkdir -p $prevCyclingFCDirs[$member]

  ln -sf ${InitialFC}/${RSTFilePrefix}.${fileDate}.nc \
    $prevCyclingFCDirs[$member]/${FCFilePrefix}.${fileDate}.nc

  ln -sf ${InitialFC}/${DIAGFilePrefix}.${fileDate}.nc \
    $prevCyclingFCDirs[$member]/${DIAGFilePrefix}.${fileDate}.nc

  @ member++
end
setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}

#TODO: enable VARBC updating between cycles
#  setenv VARBC_TABLE ${prevCyclingDADir}/${VARBC_ANA}


#------- CyclingDA ---------
#TODO: enable mean state diagnostics; only works for deterministic DA
set WorkDir = ${CyclingDADir}
set cylcTaskType = CyclingDA
set WrapperScript=${mainScriptDir}/${AppAndVerify}DA.csh
sed -e 's@wrapWorkDirsArg@CyclingDADir@' \
    -e 's@AppNameArg@da@' \
    -e 's@cylcTaskTypeArg@'${cylcTaskType}'@' \
    -e 's@wrapStateDirsArg@prevCyclingFCDirs@' \
    -e 's@wrapStatePrefixArg@'${FCFilePrefix}'@' \
    -e 's@wrapStateTypeArg@DA@' \
    -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
    -e 's@wrapWindowHRArg@'${CyclingWindowHR}'@' \
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
    -e 's@StateDirsArg@CyclingDAOutDirs@' \
    -e 's@fcLengthHRArg@'${CyclingWindowHR}'@' \
    -e 's@fcIntervalHRArg@'${CyclingWindowHR}'@' \
    fc.csh > ${JobScript}
chmod 744 ${JobScript}


#------- ExtendedMeanFC ---------
echo "Making ExtendedMeanFC job script"
set JobScript=${mainScriptDir}/ExtendedMeanFC.csh
sed -e 's@WorkDirsArg@ExtendedMeanFCDir@' \
    -e 's@StateDirsArg@MeanAnalysisDir@' \
    -e 's@fcLengthHRArg@'${ExtendedFCWindowHR}'@' \
    -e 's@fcIntervalHRArg@'${ExtendedFC_DT_HR}'@' \
    fc.csh > ${JobScript}
chmod 744 ${JobScript}


#------- ExtendedEnsFC ---------
echo "Making ExtendedEnsFC job script"
set JobScript=${mainScriptDir}/ExtendedEnsFC.csh
sed -e 's@WorkDirsArg@ExtendedEnsFCDirs@' \
    -e 's@StateDirsArg@CyclingDAOutDirs@' \
    -e 's@fcLengthHRArg@'${ExtendedFCWindowHR}'@' \
    -e 's@fcIntervalHRArg@'${ExtendedFC_DT_HR}'@' \
    fc.csh > ${JobScript}
chmod 744 ${JobScript}


#------- CalcOM{{state}}, VerifyObs{{state}}, VerifyModel{{state}} ---------
foreach state (AN BG MeanFC EnsFC)
  if (${state} == AN) then
    set myArgs = (CyclingDAOutDirs ${ANFilePrefix} ${CyclingWindowHR})
  else if (${state} == BG) then
    set myArgs = (prevCyclingFCDirs ${FCFilePrefix} ${CyclingWindowHR})
  else if (${state} == MeanFC) then
    set myArgs = (ExtendedMeanFCDir ${FCFilePrefix} ${DAVFWindowHR})
  else if (${state} == EnsFC) then
    set myArgs = (ExtendedEnsFCDirs ${FCFilePrefix} ${DAVFWindowHR})
  endif
  set cylcTaskType = CalcOM${state}
  set WrapperScript=${mainScriptDir}/${AppAndVerify}${state}.csh
  sed -e 's@wrapWorkDirsArg@Verify'${state}'Dirs@' \
      -e 's@AppNameArg@'${omm}'@' \
      -e 's@cylcTaskTypeArg@'${cylcTaskType}'@' \
      -e 's@wrapStateDirsArg@'$myArgs[1]'@' \
      -e 's@wrapStatePrefixArg@'$myArgs[2]'@' \
      -e 's@wrapStateTypeArg@'${state}'@' \
      -e 's@wrapVARBCTableArg@'${VARBC_TABLE}'@' \
      -e 's@wrapWindowHRArg@'$myArgs[3]'@' \
      -e 's@wrapDATypeArg@'${omm}'@g' \
      -e 's@wrapDAModeArg@'${omm}'@g' \
      -e 's@wrapObsListArg@OMMObsList@' \
      ${AppAndVerify}.csh > ${WrapperScript}
  chmod 744 ${WrapperScript}
  ${WrapperScript}
  rm ${WrapperScript}
end

exit 0
