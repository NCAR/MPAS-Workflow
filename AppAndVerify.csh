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
set PreparationScript=${mainScriptDir}/${preparationName}${self_taskBaseScript}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    -e 's@WindowHRTEMPLATE@wrapWindowHRTEMPLATE@' \
    -e 's@observationsListTEMPLATE@wrapObservationsListTEMPLATE@' \
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
set VFObsScript=${mainScriptDir}/VerifyObs${self_StateType}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    verifyobs.csh > ${VFObsScript}
chmod 744 ${VFObsScript}

set CompareObsScript=${mainScriptDir}/CompareObs${self_StateType}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
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

#Application cleanup
set JobScript=${mainScriptDir}/Clean${self_taskBaseScript}.csh
sed -e 's@WorkDirsTEMPLATE@'${self_WorkDirs}'@' \
    CleanAppScriptNameTEMPLATE.csh > ${JobScript}
chmod 744 ${JobScript}
