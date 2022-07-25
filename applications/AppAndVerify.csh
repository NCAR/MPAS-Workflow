#!/bin/csh -f

set self_WorkDirs = wrapWorkDirsTEMPLATE
set benchmark_WorkDirs = wrapWorkDirsBenchmarkTEMPLATE
set self_taskBaseScript = taskBaseScriptTEMPLATE
set self_inStateDirs = wrapStateDirsTEMPLATE
set self_inStatePrefix = wrapStatePrefixTEMPLATE
set self_StateType = wrapStateTypeTEMPLATE

set preparationName = PrepJEDI

echo "Making task scripts for ${self_StateType} state"

#Application preparation
set PreparationScript=${mainAppDir}/${preparationName}${self_taskBaseScript}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    -e 's@WindowHRTEMPLATE@wrapWindowHRTEMPLATE@' \
    applications/${preparationName}.csh > ${PreparationScript}
chmod 744 ${PreparationScript}

#Application
set JobScript=${mainAppDir}/${self_taskBaseScript}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    -e 's@inStateDirsTEMPLATE@'${self_inStateDirs}'@' \
    -e 's@inStatePrefixTEMPLATE@'${self_inStatePrefix}'@' \
    applications/AppScriptNameTEMPLATE.csh > ${JobScript}
chmod 744 ${JobScript}

#Application verification
set VFObsScript=${mainAppDir}/VerifyObs${self_StateType}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    applications/verifyobs.csh > ${VFObsScript}
chmod 744 ${VFObsScript}

set CompareObsScript=${mainAppDir}/CompareObs${self_StateType}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    -e 's@WorkDirsBenchmarkTEMPLATE@'${benchmark_WorkDirs}'@' \
    applications/compareobs.csh > ${CompareObsScript}
chmod 744 ${CompareObsScript}

set VFModelScript=${mainAppDir}/VerifyModel${self_StateType}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    -e 's@inStateDirsTEMPLATE@'${self_inStateDirs}'@' \
    -e 's@inStatePrefixTEMPLATE@'${self_inStatePrefix}'@' \
    applications/verifymodel.csh > ${VFModelScript}
chmod 744 ${VFModelScript}

set CompareModelScript=${mainAppDir}/CompareModel${self_StateType}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    -e 's@WorkDirsBenchmarkTEMPLATE@'${benchmark_WorkDirs}'@' \
    applications/comparemodel.csh > ${CompareModelScript}
chmod 744 ${CompareModelScript}

#Application cleanup
set JobScript=${mainAppDir}/Clean${self_taskBaseScript}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    applications/CleanAppScriptNameTEMPLATE.csh > ${JobScript}
chmod 744 ${JobScript}
