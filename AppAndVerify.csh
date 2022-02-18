#!/bin/csh -f

set self_WorkDirs = wrapWorkDirsTEMPLATE
set benchmark_WorkDirs = wrapWorkDirsBenchmarkTEMPLATE
set self_taskBaseScript = taskBaseScriptTEMPLATE
set self_inStateDirs = wrapStateDirsTEMPLATE
set self_inStatePrefix = wrapStatePrefixTEMPLATE
set self_StateType = wrapStateTypeTEMPLATE
set self_AppName = wrapAppNameTEMPLATE
set self_nOuter = wrapnOuterTEMPLATE

set preparationName = PrepJEDI
foreach name ( \
  ${preparationName}${self_taskBaseScript} \
  ${self_taskBaseScript} \
  VerifyObs${self_StateType} \
  CompareObs${self_StateType} \
  VerifyModel${self_StateType} \
  CompareModel${self_StateType} \
  Clean${self_taskBaseScript} \
)
  echo "Making $name job script for ${self_StateType} state"
end

#Application preparation
set PreparationScript=${mainScriptDir}/${preparationName}${self_taskBaseScript}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    -e 's@WindowHRTEMPLATE@wrapWindowHRTEMPLATE@' \
    -e 's@VARBCTableTEMPLATE@wrapVARBCTableTEMPLATE@' \
    -e 's@AppNameTEMPLATE@'${self_AppName}'@' \
    -e 's@AppTypeTEMPLATE@wrapAppTypeTEMPLATE@' \
    ${preparationName}.csh > ${PreparationScript}
chmod 744 ${PreparationScript}

#Application
set JobScript=${mainScriptDir}/${self_taskBaseScript}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    -e 's@inStateDirsTEMPLATE@'${self_inStateDirs}'@' \
    -e 's@inStatePrefixTEMPLATE@'${self_inStatePrefix}'@' \
    AppScriptNameTEMPLATE.csh > ${JobScript}
chmod 744 ${JobScript}

#Application verification
if ( "$self_AppName" =~ *"eda"* ) then
  #NOTE: verification not set up for multiple states yet
  set VFOBSScript=None
  set VFMODELScript=None
else
  set VFObsScript=${mainScriptDir}/VerifyObs${self_StateType}.csh
  sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
      -e 's@nOuterTEMPLATE@'${self_nOuter}'@' \
      -e 's@jediAppNameTEMPLATE@wrapjediAppNameTEMPLATE@' \
      verifyobs.csh > ${VFObsScript}
  chmod 744 ${VFObsScript}

  set CompareObsScript=${mainScriptDir}/CompareObs${self_StateType}.csh
  sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
      -e 's@jediAppNameTEMPLATE@wrapjediAppNameTEMPLATE@' \
      -e 's@WorkDirsBenchmarkTEMPLATE@'${benchmark_WorkDirs}'@' \
      compareobs.csh > ${CompareObsScript}
  chmod 744 ${CompareObsScript}

  set VFModelScript=${mainScriptDir}/VerifyModel${self_StateType}.csh
  sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
      -e 's@inStateDirsTEMPLATE@'${self_inStateDirs}'@' \
      -e 's@inStatePrefixTEMPLATE@'${self_inStatePrefix}'@' \
      verifymodel.csh > ${VFModelScript}
  chmod 744 ${VFModelScript}

  set CompareModelScript=${mainScriptDir}/CompareModel${self_StateType}.csh
  sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
      -e 's@WorkDirsBenchmarkTEMPLATE@'${benchmark_WorkDirs}'@' \
      comparemodel.csh > ${CompareModelScript}
  chmod 744 ${CompareModelScript}
endif

#Application cleanup
set JobScript=${mainScriptDir}/Clean${self_taskBaseScript}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    CleanAppScriptNameTEMPLATE.csh > ${JobScript}
chmod 744 ${JobScript}
