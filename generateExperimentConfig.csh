#!/bin/csh -f

setenv TMPDIR /glade/scratch/${USER}/temp
mkdir -p $TMPDIR

source config/benchmark.csh
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

## total number of members
# TODO: set nMembers explicitly via yaml instead of variational.nEnsDAMembers
setenv nMembers $nEnsDAMembers


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
  setenv ExperimentName ${ExperimentName}_${InitializationType}
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

# cross-application file prefixes used by SetupWorkFlow.csh
setenv FCFilePrefix mpasout
setenv ANFilePrefix an

# directory names that must be consistent across experiments in order to perform cross-experiment
# verification and/or comparison
set DataAssim = CyclingDA
set Forecast = CyclingFC
set Verification = Verification

## directory string formatter for EDA members
# used as third argument to memberDir.py
setenv flowMemPrefix "mem"
setenv flowMemNDigits 3


cat >! $mainScriptDir/config/experiment.csh << EOF
#!/bin/csh -f
if ( \$?config_experiment ) exit 0
setenv config_experiment 1

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
setenv ConfigDir ${mainScriptDir}/config
setenv ModelConfigDir ${mainScriptDir}/config/mpas


##########################
## run directory structure
##########################

## immediate subdirectories
setenv ObsWorkDir ${ExperimentDirectory}/Observations

setenv ${DataAssim}WorkDir ${ExperimentDirectory}/$DataAssim

setenv ${Forecast}WorkDir ${ExperimentDirectory}/$Forecast

setenv CyclingInflationWorkDir ${ExperimentDirectory}/CyclingInflation
setenv RTPPWorkDir \${CyclingInflationWorkDir}/RTPP
setenv ABEInflationWorkDir \${CyclingInflationWorkDir}/ABEI

setenv ExtendedFCWorkDir ${ExperimentDirectory}/ExtendedFC
setenv VerificationWorkDir ${ExperimentDirectory}/$Verification

## sub-subdirectories
# InDBDir and OutDBDir control the names of the database directories
# on input and output from jedi applications
setenv InDBDir  dbIn
setenv OutDBDir dbOut

# verification and comparison
set ObsDiagnosticsDir = diagnostic_stats/obs
set ModelDiagnosticsDir = diagnostic_stats/model
set ObsCompareDir = Compare2Benchmark/obs
set ModelCompareDir = Compare2Benchmark/model

## benchmark experiment archive
setenv Benchmark${DataAssim}WorkDir ${benchmark__ExperimentDirectory}/$DataAssim
setenv BenchmarkVerificationWorkDir ${benchmark__ExperimentDirectory}/$Verification


#####################################
## file names, prefixes, and suffixes
#####################################
## model-space
setenv RSTFilePrefix restart
setenv ICFilePrefix mpasin

setenv FCFilePrefix $FCFilePrefix
setenv fcDir fc
setenv DIAGFilePrefix diag

setenv ANFilePrefix $ANFilePrefix
setenv anDir \$ANFilePrefix
setenv BGFilePrefix bg
setenv bgDir \$BGFilePrefix

setenv OrigFileSuffix _orig

## observation-space
# for obs, geovals, and hofx-diagnostics
setenv obsPrefix      obsout
setenv geoPrefix      geoval
setenv diagPrefix     ydiags

## VarBCAnalysis is the analysis variational bias correction coefficient file
# TODO: enable VarBC updating
# -----
setenv VarBCAnalysis \${OutDBDir}/satbias_crtm_ana


#########################
# member-related settings
#########################
# TODO: move these to a cross-application config/yaml combo

## number of ensemble members (currently from variational)
setenv nMembers $nMembers

setenv flowMemPrefix $flowMemPrefix
setenv flowMemNDigits $flowMemNDigits
setenv flowMemFmt "/${flowMemPrefix}{:0${flowMemNDigits}d}"
setenv flowInstanceFmt "/instance{:0${flowMemNDigits}d}"
setenv flowMemFileFmt "_{:0${flowMemNDigits}d}"
EOF

