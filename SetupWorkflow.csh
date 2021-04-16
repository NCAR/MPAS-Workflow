#!/bin/csh -f
source config/filestructure.csh

set AppAndVerify = AppAndVerify

echo ""
echo "======================================================================"
echo "Setting up a new workflow for ${ExperimentName}"
echo "======================================================================"
echo ""

rm -rf ${mainScriptDir}
mkdir -p ${mainScriptDir}
set workflowParts = ( \
  getCycleVars.csh \
  tools \
  config \
  MeanAnalysis.csh \
  MeanBackground.csh \
  RTPPInflation.csh \
  GenerateABEInflation.csh \
)
foreach part ($workflowParts)
  cp -rP $part ${mainScriptDir}/
end

source config/tools.csh
source config/modeldata.csh
source config/obsdata.csh
source config/mpas/variables.csh

## First cycle "forecast" established offline
# TODO: Setup FirstCycleDate using a new fcinit job type and put in R1 cylc position
set thisCycleDate = $FirstCycleDate
set thisValidDate = $thisCycleDate
source getCycleVars.csh
set member = 1
while ( $member <= ${nEnsDAMembers} )
  echo ""
  find $prevCyclingFCDirs[$member] -mindepth 0 -maxdepth 0 > /dev/null
  if ($? == 0) then
    rm -r $prevCyclingFCDirs[$member]
  endif
  mkdir -p $prevCyclingFCDirs[$member]
  set fcFile = $prevCyclingFCDirs[$member]/${FCFilePrefix}.${fileDate}.nc

  set InitialMemberFC = "$firstFCDir"`${memberDir} ens $member "${firstFCMemFmt}"`
  ln -sfv ${InitialMemberFC}/${firstFCFilePrefix}.${fileDate}.nc ${fcFile}${OrigFileSuffix}
  # rm ${fcFile}
  cp -v ${fcFile}${OrigFileSuffix} ${fcFile}

  set diagFile = $prevCyclingFCDirs[$member]/${DIAGFilePrefix}.${fileDate}.nc
  ln -sfv ${InitialMemberFC}/${DIAGFilePrefix}.${fileDate}.nc ${diagFile}

  ## Add MPASJEDIDiagVariables to the next cycle bg file (if needed)
  set copyDiags = 0
  foreach var ({$MPASJEDIDiagVariables})
    ncdump -h ${fcFile} | grep -q $var
    if ( $status != 0 ) then
      @ copyDiags++
      echo "Copying MPASJEDIDiagVariables to background state"
    endif
  end
# Takes too long on command-line.  Make it part of a job (R1).
#  if ( $copyDiags > 0 ) then
#    ncks -A -v ${MPASJEDIDiagVariables} ${diagFile} ${fcFile}
#  endif
#  rm ${diagFile}

  @ member++
end
setenv VARBC_TABLE ${INITIAL_VARBC_TABLE}

#TODO: enable VARBC updating between cycles
#  setenv VARBC_TABLE ${prevCyclingDADir}/${VarBCAnalysis}


## jediPrepCyclingDA, CyclingDA, VerifyObsDA, VerifyModelDA*, CleanCyclingDA
# *VerifyModelDA is non-functional and unused
#TODO: enable VerifyObsDA for ensemble DA; only works for deterministic DA
set WorkDir = $CyclingDADirs[1]
set cylcTaskType = CyclingDA
set WrapperScript=${mainScriptDir}/${AppAndVerify}DA.csh
sed -e 's@wrapWorkDirsTEMPLATE@CyclingDADirs@' \
    -e 's@wrapWorkDirsBenchmarkTEMPLATE@BenchmarkCyclingDADirs@' \
    -e 's@AppScriptNameTEMPLATE@variational@' \
    -e 's@cylcTaskTypeTEMPLATE@'${cylcTaskType}'@' \
    -e 's@wrapStateDirsTEMPLATE@prevCyclingFCDirs@' \
    -e 's@wrapStatePrefixTEMPLATE@'${FCFilePrefix}'@' \
    -e 's@wrapStateTypeTEMPLATE@DA@' \
    -e 's@wrapVARBCTableTEMPLATE@'${VARBC_TABLE}'@' \
    -e 's@wrapWindowHRTEMPLATE@'${CyclingWindowHR}'@' \
    -e 's@wrapAppNameTEMPLATE@'${DAType}'@g' \
    -e 's@wrapjediAppNameTEMPLATE@variational@g' \
    -e 's@wrapnOuterTEMPLATE@1@g' \
    -e 's@wrapAppTypeTEMPLATE@variational@g' \
    ${AppAndVerify}.csh > ${WrapperScript}
chmod 744 ${WrapperScript}
${WrapperScript}
rm ${WrapperScript}


## CyclingFC
echo "Making CyclingFC job script"
set JobScript=${mainScriptDir}/CyclingFC.csh
sed -e 's@WorkDirsTEMPLATE@CyclingFCDirs@' \
    -e 's@StateDirsTEMPLATE@CyclingDAOutDirs@' \
    -e 's@fcLengthHRTEMPLATE@'${CyclingWindowHR}'@' \
    -e 's@fcIntervalHRTEMPLATE@'${CyclingWindowHR}'@' \
    forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## ExtendedMeanFC
echo "Making ExtendedMeanFC job script"
set JobScript=${mainScriptDir}/ExtendedMeanFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedMeanFCDirs@' \
    -e 's@StateDirsTEMPLATE@MeanAnalysisDirs@' \
    -e 's@fcLengthHRTEMPLATE@'${ExtendedFCWindowHR}'@' \
    -e 's@fcIntervalHRTEMPLATE@'${ExtendedFC_DT_HR}'@' \
    forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## ExtendedEnsFC
echo "Making ExtendedEnsFC job script"
set JobScript=${mainScriptDir}/ExtendedEnsFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedEnsFCDirs@' \
    -e 's@StateDirsTEMPLATE@CyclingDAOutDirs@' \
    -e 's@fcLengthHRTEMPLATE@'${ExtendedFCWindowHR}'@' \
    -e 's@fcIntervalHRTEMPLATE@'${ExtendedFC_DT_HR}'@' \
    forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## jediPrepHofX{{state}}, HofX{{state}}, CleanHofX{{state}}
## VerifyObs{{state}}, CompareObs{{state}},
## VerifyModel{{state}}, CompareModel{{state}}
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
  set cylcTaskType = HofX${state}
  set WrapperScript=${mainScriptDir}/${AppAndVerify}${state}.csh
  sed -e 's@wrapWorkDirsTEMPLATE@Verify'${state}'Dirs@' \
      -e 's@wrapWorkDirsBenchmarkTEMPLATE@BenchmarkVerify'${state}'Dirs@' \
      -e 's@AppScriptNameTEMPLATE@hofx@' \
      -e 's@cylcTaskTypeTEMPLATE@'${cylcTaskType}'@' \
      -e 's@wrapStateDirsTEMPLATE@'$TemplateVariables[1]'@' \
      -e 's@wrapStatePrefixTEMPLATE@'$TemplateVariables[2]'@' \
      -e 's@wrapStateTypeTEMPLATE@'${state}'@' \
      -e 's@wrapVARBCTableTEMPLATE@'${VARBC_TABLE}'@' \
      -e 's@wrapWindowHRTEMPLATE@'$TemplateVariables[3]'@' \
      -e 's@wrapAppNameTEMPLATE@hofx@g' \
      -e 's@wrapjediAppNameTEMPLATE@hofx@g' \
      -e 's@wrapnOuterTEMPLATE@0@g' \
      -e 's@wrapAppTypeTEMPLATE@hofx@g' \
      ${AppAndVerify}.csh > ${WrapperScript}
  chmod 744 ${WrapperScript}
  ${WrapperScript}
  rm ${WrapperScript}
end

exit 0
