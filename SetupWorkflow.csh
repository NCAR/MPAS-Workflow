#!/bin/csh -f
source config/filestructure.csh

set AppAndVerify = AppAndVerify

echo ""
echo "======================================================================"
echo "Setting up a new workflow"
echo "  ExperimentName: ${ExperimentName}"
echo "  mainScriptDir: ${mainScriptDir}"
echo "======================================================================"
echo ""

rm -rf ${mainScriptDir}
mkdir -p ${mainScriptDir}
set workflowParts = ( \
  GetGFSanalysis.csh \
  UngribColdStartIC.csh \
  GenerateColdStartIC.csh \
  GetWarmStartIC.csh \
  GetRDAobs.csh \
  GetNCEPFTPobs.csh \
  ObstoIODA.csh \
  getCycleVars.csh \
  tools \
  config \
  MeanAnalysis.csh \
  MeanBackground.csh \
  RTPPInflation.csh \
  GenerateABEInflation.csh \
  PrepVariational.csh \
  EnsembleOfVariational.csh \
)
foreach part ($workflowParts)
  cp -rP $part ${mainScriptDir}/
end

source config/tools.csh
source config/modeldata.csh
source config/obsdata.csh
source config/mpas/variables.csh
source config/experiment.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh

## First cycle "forecast" established offline
# TODO: Setup FirstCycleDate using a new fcinit job type and put in R1 cylc position
set thisCycleDate = $FirstCycleDate
set thisValidDate = $thisCycleDate
source getCycleVars.csh

#TODO: enable VARBC updating between cycles
#  setenv VARBC_TABLE ${prevCyclingDADir}/${VarBCAnalysis}

## PrepJEDICyclingDA, CyclingDA, VerifyObsDA, VerifyModelDA*, CleanCyclingDA
# *VerifyModelDA is non-functional and unused
#TODO: enable VerifyObsDA for ensemble DA; only works for deterministic DA
set WorkDir = $CyclingDADirs[1]
set taskBaseScript = Variational
set WrapperScript=${mainScriptDir}/${AppAndVerify}DA.csh
sed -e 's@wrapWorkDirsTEMPLATE@CyclingDADirs@' \
    -e 's@wrapWorkDirsBenchmarkTEMPLATE@BenchmarkCyclingDADirs@' \
    -e 's@AppScriptNameTEMPLATE@Variational@' \
    -e 's@taskBaseScriptTEMPLATE@'${taskBaseScript}'@' \
    -e 's@wrapStateDirsTEMPLATE@prevCyclingFCDirs@' \
    -e 's@wrapStatePrefixTEMPLATE@'${FCFilePrefix}'@' \
    -e 's@wrapStateTypeTEMPLATE@DA@' \
    -e 's@wrapWindowHRTEMPLATE@'${CyclingWindowHR}'@' \
    -e 's@wrapAppNameTEMPLATE@'${DAType}'@g' \
    -e 's@wrapjediAppNameTEMPLATE@variational@g' \
    -e 's@wrapnOuterTEMPLATE@'${nOuterIterations}'@g' \
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
    -e 's@deleteZerothForecastTEMPLATE@True@' \
    forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## ExtendedMeanFC
echo "Making ExtendedMeanFC job script"
set JobScript=${mainScriptDir}/ExtendedMeanFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedMeanFCDirs@' \
    -e 's@StateDirsTEMPLATE@MeanAnalysisDirs@' \
    -e 's@fcLengthHRTEMPLATE@'${ExtendedFCWindowHR}'@' \
    -e 's@fcIntervalHRTEMPLATE@'${ExtendedFC_DT_HR}'@' \
    -e 's@deleteZerothForecastTEMPLATE@False@' \
    forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## ExtendedEnsFC
echo "Making ExtendedEnsFC job script"
set JobScript=${mainScriptDir}/ExtendedEnsFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedEnsFCDirs@' \
    -e 's@StateDirsTEMPLATE@CyclingDAOutDirs@' \
    -e 's@fcLengthHRTEMPLATE@'${ExtendedFCWindowHR}'@' \
    -e 's@fcIntervalHRTEMPLATE@'${ExtendedFC_DT_HR}'@' \
    -e 's@deleteZerothForecastTEMPLATE@False@' \
    forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## PrepJEDIHofX{{state}}, HofX{{state}}, CleanHofX{{state}}
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
  set taskBaseScript = HofX${state}
  set WrapperScript=${mainScriptDir}/${AppAndVerify}${state}.csh
  sed -e 's@wrapWorkDirsTEMPLATE@Verify'${state}'Dirs@' \
      -e 's@wrapWorkDirsBenchmarkTEMPLATE@BenchmarkVerify'${state}'Dirs@' \
      -e 's@AppScriptNameTEMPLATE@HofX@' \
      -e 's@taskBaseScriptTEMPLATE@'${taskBaseScript}'@' \
      -e 's@wrapStateDirsTEMPLATE@'$TemplateVariables[1]'@' \
      -e 's@wrapStatePrefixTEMPLATE@'$TemplateVariables[2]'@' \
      -e 's@wrapStateTypeTEMPLATE@'${state}'@' \
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
