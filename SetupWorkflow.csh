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
  ${MPASGridDescriptor} \
  MeanAnalysis.csh \
  MeanBackground.csh \
  RTPPInflation.csh \
  GenerateABEInflation.csh \
)
foreach part ($cyclingParts)
  cp -rP $part ${mainScriptDir}/
end

## First cycle "forecast" established offline
# TODO: Setup FirstCycleDate using a new fcinit job type and put in R1 cylc position
set thisCycleDate = $FirstCycleDate
set thisValidDate = $thisCycleDate
source getCycleVars.csh
set member = 1
while ( $member <= ${nEnsDAMembers} )
  if ( "$DAType" =~ *"eda"* ) then
    set InitialFC = "$firstEnsFCDir"`${memberDir} ens $member "${firstEnsFCMemFmt}"`
    set FirstCycleFilePrefix = ${FCFilePrefix}
  else
    set InitialFC = $firstDetermFCDir
    set FirstCycleFilePrefix = ${RSTFilePrefix}
  endif
  rm -r $prevCyclingFCDirs[$member]
  mkdir -p $prevCyclingFCDirs[$member]

  set fcFile = $prevCyclingFCDirs[$member]/${FCFilePrefix}.${fileDate}.nc
  ln -sfv ${InitialFC}/${FirstCycleFilePrefix}.${fileDate}.nc ${fcFile}${OrigFileSuffix}
  # rm ${fcFile}
  cp -v ${fcFile}${OrigFileSuffix} ${fcFile}

  set diagFile = $prevCyclingFCDirs[$member]/${DIAGFilePrefix}.${fileDate}.nc
  ln -sf ${InitialFC}/${DIAGFilePrefix}.${fileDate}.nc ${diagFile}

  ## Add MPASDiagVariables to the next cycle bg file (if needed)
  set copyDiags = 0
  foreach var ({$MPASDiagVariables})
    ncdump -h ${fcFile} | grep $var
    if ( $status != 0 ) then
      @ copyDiags++
    endif
  end
# Takes too long on command-line.  Make it part of a job (R1).
#  if ( $copyDiags > 0 ) then
#    ncks -A -v ${MPASDiagVariables} ${diagFile} ${fcFile}
#  endif
#  rm ${diagFile}

  @ member++
end
setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}

#TODO: enable VARBC updating between cycles
#  setenv VARBC_TABLE ${prevCyclingDADir}/${VARBC_ANA}


#------- CyclingDA ---------
#TODO: enable mean state diagnostics; only works for deterministic DA
set WorkDir = $CyclingDADirs[1]
set cylcTaskType = CyclingDA
set WrapperScript=${mainScriptDir}/${AppAndVerify}DA.csh
sed -e 's@wrapWorkDirsTEMPLATE@CyclingDADirs@' \
    -e 's@AppScriptNameTEMPLATE@da@' \
    -e 's@cylcTaskTypeTEMPLATE@'${cylcTaskType}'@' \
    -e 's@wrapStateDirsTEMPLATE@prevCyclingFCDirs@' \
    -e 's@wrapStatePrefixTEMPLATE@'${FCFilePrefix}'@' \
    -e 's@wrapStateTypeTEMPLATE@DA@' \
    -e 's@wrapVARBCTableTEMPLATE@'${VARBC_TABLE}'@' \
    -e 's@wrapWindowHRTEMPLATE@'${CyclingWindowHR}'@' \
    -e 's@wrapAppNameTEMPLATE@'${DAType}'@g' \
    -e 's@wrapjediAppNameTEMPLATE@variational@g' \
    -e 's@wrapnOuterTEMPLATE@1@g' \
    -e 's@wrapAppTypeTEMPLATE@da@g' \
    -e 's@wrapObsListTEMPLATE@DAObsList@' \
    ${AppAndVerify}.csh > ${WrapperScript}
chmod 744 ${WrapperScript}
${WrapperScript}
rm ${WrapperScript}


#------- CyclingFC ---------
echo "Making CyclingFC job script"
set JobScript=${mainScriptDir}/CyclingFC.csh
sed -e 's@WorkDirsTEMPLATE@CyclingFCDirs@' \
    -e 's@StateDirsTEMPLATE@CyclingDAOutDirs@' \
    -e 's@fcLengthHRTEMPLATE@'${CyclingWindowHR}'@' \
    -e 's@fcIntervalHRTEMPLATE@'${CyclingWindowHR}'@' \
    fc.csh > ${JobScript}
chmod 744 ${JobScript}


#------- ExtendedMeanFC ---------
echo "Making ExtendedMeanFC job script"
set JobScript=${mainScriptDir}/ExtendedMeanFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedMeanFCDirs@' \
    -e 's@StateDirsTEMPLATE@MeanAnalysisDirs@' \
    -e 's@fcLengthHRTEMPLATE@'${ExtendedFCWindowHR}'@' \
    -e 's@fcIntervalHRTEMPLATE@'${ExtendedFC_DT_HR}'@' \
    fc.csh > ${JobScript}
chmod 744 ${JobScript}


#------- ExtendedEnsFC ---------
echo "Making ExtendedEnsFC job script"
set JobScript=${mainScriptDir}/ExtendedEnsFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedEnsFCDirs@' \
    -e 's@StateDirsTEMPLATE@CyclingDAOutDirs@' \
    -e 's@fcLengthHRTEMPLATE@'${ExtendedFCWindowHR}'@' \
    -e 's@fcIntervalHRTEMPLATE@'${ExtendedFC_DT_HR}'@' \
    fc.csh > ${JobScript}
chmod 744 ${JobScript}


#------- CalcOM{{state}}, VerifyObs{{state}}, VerifyModel{{state}} ---------
foreach state (AN BG EnsMeanBG MeanFC EnsFC)
  if (${state} == AN) then
    set TemplateVariables = (CyclingDAOutDirs ${ANFilePrefix} ${DAVFWindowHR})
  else if (${state} == BG) then
    set TemplateVariables = (prevCyclingFCDirs ${FCFilePrefix} ${DAVFWindowHR})
  else if (${state} == EnsMeanBG) then
    set TemplateVariables = (MeanBackgroundDirs ${FCFilePrefix} ${DAVFWindowHR})
  else if (${state} == MeanFC) then
    set TemplateVariables = (ExtendedMeanFCDirs ${FCFilePrefix} ${FCVFWindowHR})
  else if (${state} == EnsFC) then
    set TemplateVariables = (ExtendedEnsFCDirs ${FCFilePrefix} ${FCVFWindowHR})
  endif
  set cylcTaskType = CalcOM${state}
  set WrapperScript=${mainScriptDir}/${AppAndVerify}${state}.csh
  sed -e 's@wrapWorkDirsTEMPLATE@Verify'${state}'Dirs@' \
      -e 's@AppScriptNameTEMPLATE@'${omm}'@' \
      -e 's@cylcTaskTypeTEMPLATE@'${cylcTaskType}'@' \
      -e 's@wrapStateDirsTEMPLATE@'$TemplateVariables[1]'@' \
      -e 's@wrapStatePrefixTEMPLATE@'$TemplateVariables[2]'@' \
      -e 's@wrapStateTypeTEMPLATE@'${state}'@' \
      -e 's@wrapVARBCTableTEMPLATE@'${VARBC_TABLE}'@' \
      -e 's@wrapWindowHRTEMPLATE@'$TemplateVariables[3]'@' \
      -e 's@wrapAppNameTEMPLATE@'${omm}'@g' \
      -e 's@wrapjediAppNameTEMPLATE@hofx@g' \
      -e 's@wrapnOuterTEMPLATE@0@g' \
      -e 's@wrapAppTypeTEMPLATE@'${omm}'@g' \
      -e 's@wrapObsListTEMPLATE@OMMObsList@' \
      ${AppAndVerify}.csh > ${WrapperScript}
  chmod 744 ${WrapperScript}
  ${WrapperScript}
  rm ${WrapperScript}
end

exit 0
