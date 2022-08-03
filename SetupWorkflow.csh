#!/bin/csh -f

## create experiment environment
source generateExperimentConfig.csh

set workflowParts = ( \
  GetGDASanalysis.csh \
  GetGFSanalysis.csh \
  UngribColdStartIC.csh \
  GenerateColdStartIC.csh \
  GetWarmStartIC.csh \
  GetObs.csh \
  ObsToIODA.csh \
  getCycleVars.csh \
  tools \
  config \
  scenarios \
  MeanAnalysis.csh \
  MeanBackground.csh \
  PrepRTPP.csh \
  RTPP.csh \
  CleanRTPP.csh \
  GenerateABEInflation.csh \
  PrepVariational.csh \
  EnsembleOfVariational.csh \
  include \
)
foreach part ($workflowParts)
  cp -rP $part ${mainScriptDir}/
end

cd ${mainScriptDir}

## load the workflow settings
source config/workflow.csh

cd -

set AppAndVerify = AppAndVerify

## PrepJEDIVariational, Variational, VerifyObsDA, VerifyModelDA*, CleanVariational
# *VerifyModelDA is non-functional and unused
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
    ${AppAndVerify}.csh > ${WrapperScript}
chmod 744 ${WrapperScript}
${WrapperScript}
rm ${WrapperScript}


## Forecast
echo "Making Forecast job script"
set JobScript=${mainScriptDir}/Forecast.csh
sed -e 's@WorkDirsTEMPLATE@CyclingFCDirs@' \
    -e 's@StateDirsTEMPLATE@CyclingDAOutDirs@' \
    -e 's@deleteZerothForecastTEMPLATE@True@' \
    forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## ExtendedMeanFC
echo "Making ExtendedMeanFC job script"
set JobScript=${mainScriptDir}/ExtendedMeanFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedMeanFCDirs@' \
    -e 's@StateDirsTEMPLATE@MeanAnalysisDirs@' \
    -e 's@deleteZerothForecastTEMPLATE@False@' \
    forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## ExtendedEnsFC
echo "Making ExtendedEnsFC job script"
set JobScript=${mainScriptDir}/ExtendedEnsFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedEnsFCDirs@' \
    -e 's@StateDirsTEMPLATE@CyclingDAOutDirs@' \
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
      ${AppAndVerify}.csh > ${WrapperScript}
  chmod 744 ${WrapperScript}
  ${WrapperScript}
  rm ${WrapperScript}
end

exit 0
