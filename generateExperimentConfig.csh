#!/bin/csh -f

setenv TMPDIR /glade/scratch/${USER}/temp
mkdir -p $TMPDIR

source config/benchmark.csh
source config/firstbackground.csh
source config/externalanalyses.csh
source config/naming.csh
source config/workflow.csh
source config/applications/rtpp.csh
source config/applications/variational.csh
source config/model.csh

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "experiment" key of scenarioConfig
setenv baseConfig scenarios/base/experiment.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig experiment"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig experiment"

# ParentDirectory parts
$setLocal ParentDirectoryPrefix
$setLocal ParentDirectorySuffix

# ExperimentUserDir
setenv ExperimentUserDir "`$getLocalOrNone ExperimentUserDir`"
if ("$ExperimentUserDir" == None) then
  setenv ExperimentUserDir ${USER}
endif

# ExperimentUserPrefix
setenv ExperimentUserPrefix "`$getLocalOrNone ExperimentUserPrefix`"
if ("$ExperimentUserPrefix" == None) then
  setenv ExperimentUserPrefix ${USER}_
endif

# ExperimentName
setenv ExperimentName "`$getLocalOrNone ExperimentName`"

# ExpSuffix
$setLocal ExpSuffix

## ParentDirectory
# where this experiment is located
setenv ParentDirectory ${ParentDirectoryPrefix}/${ExperimentUserDir}/${ParentDirectorySuffix}

## experiment name
if ("$ExperimentName" == None) then
  # derive experiment title parts from critical config elements
  #(1) DAType
  set ExpBase = ${DAType}

  #(2) ensemble-related settings
  set ExpEnsSuffix = ''
  if ($nMembers > 1) then
    set ExpBase = eda_${ExpBase}
    if ($EDASize > 1) then
      set ExpEnsSuffix = '_NMEM'${nDAInstances}x${EDASize}
      if ($MinimizerAlgorithm == $BlockEDA) then
        set ExpEnsSuffix = ${ExpEnsSuffix}Block
      endif
    else
      set ExpEnsSuffix = '_NMEM'${nMembers}
    endif
    if (${rtpp__relaxationFactor} != "0.0") set ExpEnsSuffix = ${ExpEnsSuffix}_RTPP${rtpp__relaxationFactor}
    if (${SelfExclusion} == True) set ExpEnsSuffix = ${ExpEnsSuffix}_SelfExclusion
    if (${ABEInflation} == True) set ExpEnsSuffix = ${ExpEnsSuffix}_ABEI_BT${ABEIChannel}
  endif

  #(3) inner iteration counts
  set ExpIterSuffix = ''
  foreach nInner ($nInnerIterations)
    set ExpIterSuffix = ${ExpIterSuffix}-${nInner}
  end
  if ( $nOuterIterations > 0 ) then
    set ExpIterSuffix = ${ExpIterSuffix}-iter
  endif

  #(4) observation selection
  setenv ExpObsSuffix ''
  foreach obs ($observations)
    set isBench = False
    foreach benchObs ($benchmarkObservations)
      if ("$obs" =~ *"$benchObs"*) then
        set isBench = True
      endif
    end
    if ( $isBench == False ) then
      setenv ExpObsSuffix ${ExpObsSuffix}_${obs}
    endif
  end

  setenv ExperimentName ${ExpBase}
  setenv ExperimentName ${ExperimentName}${ExpIterSuffix}
  setenv ExperimentName ${ExperimentName}${ExpObsSuffix}
  setenv ExperimentName ${ExperimentName}${ExpEnsSuffix}
  setenv ExperimentName ${ExperimentName}_${MeshesDescriptor}
  #setenv ExperimentName ${ExperimentName}_${firstbackground__resource}
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

setenv CyclingInflationWorkDir ${ExperimentDirectory}/\$cyclingInflationWorkDir
setenv RTPPWorkDir ${ExperimentDirectory}/\$rTPPWorkDir
setenv ABEInflationWorkDir ${ExperimentDirectory}/\$aBEInflationWorkDir

setenv ExtendedFCWorkDir ${ExperimentDirectory}/\$extendedFCWorkDir
setenv VerificationWorkDir ${ExperimentDirectory}/\$verificationWorkDir

setenv ExternalAnalysisWorkDir ${ExperimentDirectory}/\$externalAnalysisWorkDir/${externalanalyses__resource}/${outerMesh}
setenv ExternalAnalysisWorkDirInner ${ExperimentDirectory}/\$externalAnalysisWorkDir/${externalanalyses__resource}/${innerMesh}
setenv ExternalAnalysisWorkDirEnsemble ${ExperimentDirectory}/\$externalAnalysisWorkDir/${externalanalyses__resource}/${ensembleMesh}

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
  | sed 's@{{ExternalAnalysisWorkDir}}@'\${ExternalAnalysisWorkDir}'@' \
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

