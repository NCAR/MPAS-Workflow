#!/bin/csh -f

setenv TMPDIR /glade/scratch/${USER}/temp
mkdir -p $TMPDIR

source config/naming.csh

if ( ${ExperimentName} == None || ${ExperimentName} == "" ) then
  echo "ExperimentName(${ExperimentName}) must be defined"
  exit 1
endif
setenv ExperimentName ${ExperimentUserPrefix}${ExperimentName}
setenv ExperimentName ${ExperimentName}${ExpSuffix}

## absolute experiment directory
setenv ExperimentDirectory ${ParentDirectory}/${ExperimentName}
setenv mainScriptDir ${ExperimentDirectory}/${PackageBaseName}

echo ""
echo "======================================================================"
echo "Setting up a new workflow"
echo "  ExperimentName: ${ExperimentName}"
echo "  mainScriptDir: ${mainScriptDir}"
echo "======================================================================"
echo ""

rm -rf ${mainScriptDir}
mkdir -p $mainScriptDir/config

cat >! $mainScriptDir/config/experiment.csh << EOF
#!/bin/csh -f
if ( \$?config_experiment ) exit 0
setenv config_experiment 1

source config/benchmark.csh
source config/auto/externalanalyses.csh
source config/auto/firstbackground.csh
source config/auto/model.csh
source config/naming.csh
source config/auto/staticstream.csh
source config/auto/workflow.csh

###################
# scratch directory
###################
setenv TMPDIR $TMPDIR


########################
## primary run directory
########################
setenv ParentDirectory ${ParentDirectory}
setenv ExperimentName ${ExperimentName}
setenv ExperimentDirectory ${ExperimentDirectory}
setenv PackageBaseName ${PackageBaseName}
setenv mainScriptDir ${mainScriptDir}


#############################
## config directory structure
#############################
setenv ConfigDir ${mainScriptDir}/\$configDir
setenv ModelConfigDir ${mainScriptDir}/\$modelConfigDir


##########################
## run directory structure
##########################

## immediate subdirectories
setenv ObsWorkDir ${ExperimentDirectory}/\$obsWorkDir

setenv ${DataAssim}WorkDir ${ExperimentDirectory}/\$dataAssimWorkDir

setenv ${Forecast}WorkDir ${ExperimentDirectory}/\$forecastWorkDir

setenv CyclingInflationWorkDir ${ExperimentDirectory}/\$cyclingInflationWorkDir
setenv RTPPWorkDir ${ExperimentDirectory}/\$rTPPWorkDir
setenv ABEInflationWorkDir ${ExperimentDirectory}/\$aBEInflationWorkDir

setenv ExtendedFCWorkDir ${ExperimentDirectory}/\$extendedFCWorkDir
setenv VerificationWorkDir ${ExperimentDirectory}/\$verificationWorkDir

setenv ExternalAnalysisWorkDir ${ExperimentDirectory}/\$externalAnalysisWorkDir/\${externalanalyses__resource}
if ("\${outerMesh}" != None) then
  setenv ExternalAnalysisWorkDirOuter ${ExperimentDirectory}/\$externalAnalysisWorkDir/\${outerMesh}
else
  setenv ExternalAnalysisWorkDirOuter None
endif
if ("\${innerMesh}" != None) then
  setenv ExternalAnalysisWorkDirInner ${ExperimentDirectory}/\$externalAnalysisWorkDir/\${innerMesh}
else
  setenv ExternalAnalysisWorkDirInner None
endif
if ("\${ensembleMesh}" != None) then
  setenv ExternalAnalysisWorkDirEnsemble ${ExperimentDirectory}/\$externalAnalysisWorkDir/\${ensembleMesh}
else
  setenv ExternalAnalysisWorkDirEnsemble None
endif

#if ("\${outerMesh}" != None) then
#  setenv FirstBackgroundDirOuter ${ExperimentDirectory}/\$forecastWorkDir/template-\${outerMesh}/\${FirstCycleDate}
#else
#  setenv FirstBackgroundDirOuter None
#endif
#
#if ("\${innerMesh}" != None) then
#  setenv FirstBackgroundDirInner ${ExperimentDirectory}/\$forecastWorkDir/template-\${innerMesh}/\${FirstCycleDate}
#else
#  setenv FirstBackgroundDirInner None
#endif
#
#if ("\${ensembleMesh}" != None) then
#  setenv FirstBackgroundDirEnsemble ${ExperimentDirectory}/\$forecastWorkDir/template-\${ensembleMesh}/\${FirstCycleDate}
#else
#  setenv FirstBackgroundDirEnsemble None
#endif

## benchmark experiment archive
setenv Benchmark${DataAssim}WorkDir \${benchmark__ExperimentDirectory}/\$dataAssimWorkDir
setenv BenchmarkVerificationWorkDir \${benchmark__ExperimentDirectory}/\$verificationWorkDir


#############################
# static stream file settings
#############################
## file date for first background
set yy = \`echo "\${FirstCycleDate}" | cut -c 1-4\`
set mm = \`echo "\${FirstCycleDate}" | cut -c 5-6\`
set dd = \`echo "\${FirstCycleDate}" | cut -c 7-8\`
set hh = \`echo "\${FirstCycleDate}" | cut -c 9-10\`

setenv FirstFileDate \${yy}-\${mm}-\${dd}_\${hh}.00.00

if ("\$externalanalyses__resource" != None) then
  setenv StaticFieldsDirOuter \`echo "\${staticstream__directoryOuter}" \
    | sed 's@{{ExternalAnalysisWorkDir}}@'\${ExternalAnalysisWorkDirOuter}'@' \
    \`
  setenv StaticFieldsDirInner \`echo "\${staticstream__directoryInner}" \
    | sed 's@{{ExternalAnalysisWorkDir}}@'\${ExternalAnalysisWorkDirInner}'@' \
    \`
  setenv StaticFieldsDirEnsemble \`echo "\${staticstream__directoryEnsemble}" \
    | sed 's@{{ExternalAnalysisWorkDir}}@'\${ExternalAnalysisWorkDirEnsemble}'@' \
    \`
  setenv staticMemFmt "\${staticstream__memberFormatOuter}"

  setenv StaticFieldsFileOuter \${staticstream__filePrefixOuter}.\${FirstFileDate}.nc
  setenv StaticFieldsFileInner \${staticstream__filePrefixInner}.\${FirstFileDate}.nc
  setenv StaticFieldsFileEnsemble \${staticstream__filePrefixEnsemble}.\${FirstFileDate}.nc
else
  setenv StaticFieldsDirOuter None
  setenv StaticFieldsDirInner None
  setenv StaticFieldsDirEnsemble None

  setenv staticMemFmt None

  setenv StaticFieldsFileOuter None
  setenv StaticFieldsFileInner None
  setenv StaticFieldsFileEnsemble None
endif
EOF

if ( ! -e include/variables/auto/experiment.rc ) then
cat >! include/variables/auto/experiment.rc << EOF
{% set mainScriptDir = "${mainScriptDir}" %}
{% set title = "${PackageBaseName}--${ExperimentName}" %}
EOF

endif
