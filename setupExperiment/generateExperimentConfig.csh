#!/bin/csh -f

setenv TMPDIR /glade/scratch/${USER}/temp
mkdir -p $TMPDIR

source config/benchmark.csh
source config/firstbackground.csh
source config/externalanalyses.csh
source config/naming.csh
source config/workflow.csh
source config/model.csh

if ( ${ExperimentName} == None || ${ExperimentName} == "" ) then
  echo "ExperimentName(${ExperimentName}) must be defined"
  exit 1
endif
setenv ExperimentName ${ExperimentUserPrefix}${ExperimentName}
setenv ExperimentName ${ExperimentName}${ExpSuffix}

## absolute experiment directory
setenv ExperimentDirectory ${ParentDirectory}/${ExperimentName}
setenv PackageBaseName MPAS-Workflow
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

source config/naming.csh # temporary, source directly in dependent scripts

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
#setenv FirstBackgroundDirOuter ${ExperimentDirectory}/\$forecastWorkDir/template-$outerMesh/${FirstCycleDate}
#setenv FirstBackgroundDirInner ${ExperimentDirectory}/\$forecastWorkDir/template-$innerMesh/${FirstCycleDate}
#setenv FirstBackgroundDirEnsemble ${ExperimentDirectory}/\$forecastWorkDir/template-$ensembleMesh/${FirstCycleDate}

setenv CyclingInflationWorkDir ${ExperimentDirectory}/\$cyclingInflationWorkDir
setenv RTPPWorkDir ${ExperimentDirectory}/\$rTPPWorkDir
setenv ABEInflationWorkDir ${ExperimentDirectory}/\$aBEInflationWorkDir

setenv ExtendedFCWorkDir ${ExperimentDirectory}/\$extendedFCWorkDir
setenv VerificationWorkDir ${ExperimentDirectory}/\$verificationWorkDir

setenv ExternalAnalysisWorkDir ${ExperimentDirectory}/\$externalAnalysisWorkDir/${externalanalyses__resource}
setenv ExternalAnalysisWorkDirOuter ${ExperimentDirectory}/\$externalAnalysisWorkDir/${outerMesh}
setenv ExternalAnalysisWorkDirInner ${ExperimentDirectory}/\$externalAnalysisWorkDir/${innerMesh}
setenv ExternalAnalysisWorkDirEnsemble ${ExperimentDirectory}/\$externalAnalysisWorkDir/${ensembleMesh}

## benchmark experiment archive
setenv Benchmark${DataAssim}WorkDir ${benchmark__ExperimentDirectory}/\$dataAssimWorkDir
setenv BenchmarkVerificationWorkDir ${benchmark__ExperimentDirectory}/\$verificationWorkDir


#########################
# member-related settings
#########################
# TODO: move these to a cross-application config/yaml combo

## number of ensemble members (currently from firstbackground)
setenv nMembers $nMembers

#############################
# static stream file settings
#############################
## file date for first background
set yy = `echo ${FirstCycleDate} | cut -c 1-4`
set mm = `echo ${FirstCycleDate} | cut -c 5-6`
set dd = `echo ${FirstCycleDate} | cut -c 7-8`
set hh = `echo ${FirstCycleDate} | cut -c 9-10`
setenv FirstFileDate \${yy}-\${mm}-\${dd}_\${hh}.00.00

setenv StaticFieldsDirOuter \`echo "$firstbackground__staticDirectoryOuter" \
  | sed 's@{{ExternalAnalysisWorkDir}}@'\${ExternalAnalysisWorkDirOuter}'@' \
  | sed 's@{{FirstCycleDate}}@'${FirstCycleDate}'@' \
  \`
setenv StaticFieldsDirInner \`echo "$firstbackground__staticDirectoryInner" \
  | sed 's@{{ExternalAnalysisWorkDir}}@'\${ExternalAnalysisWorkDirInner}'@' \
  | sed 's@{{FirstCycleDate}}@'${FirstCycleDate}'@' \
  \`
setenv StaticFieldsDirEnsemble \`echo "$firstbackground__staticDirectoryEnsemble" \
  | sed 's@{{ExternalAnalysisWorkDir}}@'\${ExternalAnalysisWorkDirEnsemble}'@' \
  | sed 's@{{FirstCycleDate}}@'${FirstCycleDate}'@' \
  \`
setenv staticMemFmt "${firstbackground__memberFormatOuter}"

setenv StaticFieldsFileOuter ${firstbackground__staticPrefixOuter}.\${FirstFileDate}.nc
setenv StaticFieldsFileInner ${firstbackground__staticPrefixInner}.\${FirstFileDate}.nc
setenv StaticFieldsFileEnsemble ${firstbackground__staticPrefixEnsemble}.\${FirstFileDate}.nc
EOF

if ( ! -e include/variables/auto/experiment.rc ) then
cat >! include/variables/auto/experiment.rc << EOF
{% set mainScriptDir = "${mainScriptDir}" %}
{% set nMembers = ${nMembers} %} #integer
{% set allMembers = range(1, $nMembers+1, 1) %}
EOF

endif