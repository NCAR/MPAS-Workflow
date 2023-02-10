#!/bin/csh -f

## load the workflow settings

# experiment provides mainScriptDir, DAApplication
source config/auto/experiment.csh
echo "DAApplication = ${DAApplication}"

# workflow provides CyclingWindowHR, DAVFWindowHR, FCVFWindowHR, FirstCycleDate
source config/auto/workflow.csh

# naming provides FCFilePrefix, ANFilePrefix
source config/auto/naming.csh

set standaloneApplications = ( \
  CleanRTPP.csh \
  EnsembleOfVariational.csh \
  ExternalAnalysisToMPAS.csh \
  Forecast.csh \
  GenerateABEInflation.csh \
  GetGDASAnalysisFromFTP.csh \
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
  PrepEnKF.csh \
  EnKFObserver.csh \
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

set AppAndVerify = AppAndVerify

if (${DAApplication} != None) then
  ## PrepJEDIVariational, Variational, CleanVariational
  ## OR
  ## PrepJEDIEnKF, EnKF, CleanEnKF
  ## PLUS
  ## VerifyObsDA*, VerifyModelDA**
  # * VerifyObsDA only works for single-member cycling
  # ** VerifyModelDA is non-functional and unused
  set WrapperScript=${mainAppDir}/${AppAndVerify}DA.csh
  sed -e 's@wrapWorkDirsTEMPLATE@CyclingDADirs@' \
      -e 's@wrapWorkDirsBenchmarkTEMPLATE@BenchmarkCyclingDADirs@' \
      -e 's@AppScriptNameTEMPLATE@'${DAApplication}'@' \
      -e 's@taskBaseScriptTEMPLATE@'${DAApplication}'@' \
      -e 's@wrapStateDirsTEMPLATE@prevCyclingFCDirs@' \
      -e 's@wrapStatePrefixTEMPLATE@'${FCFilePrefix}'@' \
      -e 's@wrapStateTypeTEMPLATE@DA@' \
      -e 's@wrapWindowHRTEMPLATE@'${CyclingWindowHR}'@' \
      applications/${AppAndVerify}.csh > ${WrapperScript}
  chmod 744 ${WrapperScript}
  ${WrapperScript}
  rm ${WrapperScript}
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
