#!/bin/csh -f

# ArgExpConfigType: either Cycling or Base
set ArgExpConfigType = "$1"

## create experiment environment
source setupExperiment/${ArgExpConfigType}.csh

set standaloneApplications = ( \
  CleanRTPP.csh \
  EnsembleOfVariational.csh \
  ExternalAnalysisToMPAS.csh \
  GenerateABEInflation.csh \
  GetGFSAnalysisFromRDA.csh \
  GetGFSAnalysisFromFTP.csh \
  GetObs.csh \
  LinkExternalAnalysis.csh \
  LinkWarmStartBackgrounds.csh \
  MeanAnalysis.csh \
  MeanBackground.csh \
  ObsToIODA.csh \
  PrepRTPP.csh \
  PrepVariational.csh \
  RTPP.csh \
  UngribExternalAnalysis.csh \
)
setenv mainAppDir ${mainScriptDir}/applications
mkdir -p ${mainAppDir}
foreach app ($standaloneApplications)
  cp -rP applications/$app ${mainAppDir}/
end

set configParts = ( \
  config \
  getCycleVars.csh \
  include \
  scenarios \
  suites \
  test \
  tools \
)
foreach part ($configParts)
  cp -rP $part ${mainScriptDir}/
end

cd ${mainScriptDir}

## load the workflow settings
source config/auto/workflow.csh
source config/auto/externalanalyses.csh

cd -

set AppAndVerify = AppAndVerify

## PrepJEDIVariational, Variational, VerifyObsDA, VerifyModelDA*, CleanVariational
# *VerifyModelDA is non-functional and unused
set taskBaseScript = Variational
set WrapperScript=${mainAppDir}/${AppAndVerify}DA.csh
sed -e 's@wrapWorkDirsTEMPLATE@CyclingDADirs@' \
    -e 's@wrapWorkDirsBenchmarkTEMPLATE@BenchmarkCyclingDADirs@' \
    -e 's@AppScriptNameTEMPLATE@Variational@' \
    -e 's@taskBaseScriptTEMPLATE@'${taskBaseScript}'@' \
    -e 's@wrapStateDirsTEMPLATE@prevCyclingFCDirs@' \
    -e 's@wrapStatePrefixTEMPLATE@'${FCFilePrefix}'@' \
    -e 's@wrapStateTypeTEMPLATE@DA@' \
    -e 's@wrapWindowHRTEMPLATE@'${CyclingWindowHR}'@' \
    applications/${AppAndVerify}.csh > ${WrapperScript}
chmod 744 ${WrapperScript}
${WrapperScript}
rm ${WrapperScript}


## ColdForecast
if ("$externalanalyses__resource" != None) then
  echo "Making ColdForecast job script"
  set JobScript=${mainAppDir}/ColdForecast.csh
  sed -e 's@WorkDirsTEMPLATE@CyclingFCDirs@' \
      -e 's@StateDirsTEMPLATE@ExternalAnalysisDirOuters@' \
      -e 's@StatePrefixTEMPLATE@'${externalanalyses__filePrefixOuter}'@' \
      applications/forecast.csh > ${JobScript}
  chmod 744 ${JobScript}
endif

## Forecast
echo "Making Forecast job script"
set JobScript=${mainAppDir}/Forecast.csh
sed -e 's@WorkDirsTEMPLATE@CyclingFCDirs@' \
    -e 's@StateDirsTEMPLATE@CyclingDAOutDirs@' \
    -e 's@StatePrefixTEMPLATE@'${ANFilePrefix}'@' \
    applications/forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## ExtendedMeanFC
echo "Making ExtendedMeanFC job script"
set JobScript=${mainAppDir}/ExtendedMeanFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedMeanFCDirs@' \
    -e 's@StateDirsTEMPLATE@MeanAnalysisDirs@' \
    -e 's@StatePrefixTEMPLATE@'${ANFilePrefix}'@' \
    applications/forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## ExtendedEnsFC
echo "Making ExtendedEnsFC job script"
set JobScript=${mainAppDir}/ExtendedEnsFC.csh
sed -e 's@WorkDirsTEMPLATE@ExtendedEnsFCDirs@' \
    -e 's@StateDirsTEMPLATE@CyclingDAOutDirs@' \
    -e 's@StatePrefixTEMPLATE@'${ANFilePrefix}'@' \
    applications/forecast.csh > ${JobScript}
chmod 744 ${JobScript}


## ExtendedFCFromExternalAnalysis
if ("$externalanalyses__resource" != None) then
  echo "Making ExtendedFCFromExternalAnalysis job script"
  set JobScript=${mainAppDir}/ExtendedFCFromExternalAnalysis.csh
  sed -e 's@WorkDirsTEMPLATE@ExtendedMeanFCDirs@' \
      -e 's@StateDirsTEMPLATE@ExternalAnalysisDirOuters@' \
      -e 's@StatePrefixTEMPLATE@'${externalanalyses__filePrefixOuter}'@' \
      applications/forecast.csh > ${JobScript}
  chmod 744 ${JobScript}
endif

## PrepJEDIHofX{{state}}, HofX{{state}}, CleanHofX{{state}}
## VerifyObs{{state}}, CompareObs{{state}},
## VerifyModel{{state}}, CompareModel{{state}}
foreach state (AN BG EnsMeanBG MeanFC EnsFC ExternalAnalysis)
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
#  else if (${state} == ExternalAnalysis) then
#    set TemplateVariables = (ExtendedMeanFCDirs ${FCFilePrefix} ${FCVFWindowHR})
  endif
  set taskBaseScript = HofX${state}
  set WrapperScript=${mainAppDir}/${AppAndVerify}${state}.csh
  sed -e 's@wrapWorkDirsTEMPLATE@Verify'${state}'Dirs@' \
      -e 's@wrapWorkDirsBenchmarkTEMPLATE@BenchmarkVerify'${state}'Dirs@' \
      -e 's@AppScriptNameTEMPLATE@HofX@' \
      -e 's@taskBaseScriptTEMPLATE@'${taskBaseScript}'@' \
      -e 's@wrapStateDirsTEMPLATE@'$TemplateVariables[1]'@' \
      -e 's@wrapStatePrefixTEMPLATE@'$TemplateVariables[2]'@' \
      -e 's@wrapStateTypeTEMPLATE@'${state}'@' \
      -e 's@wrapWindowHRTEMPLATE@'$TemplateVariables[3]'@' \
      applications/${AppAndVerify}.csh > ${WrapperScript}
  chmod 744 ${WrapperScript}
  ${WrapperScript}
  rm ${WrapperScript}
end

exit 0
