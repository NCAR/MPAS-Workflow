#!/bin/csh -f

if ( $?config_experiment ) exit 0
setenv config_experiment 1

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

# ExperimentUser
set get = "`$getLocalOrNone ExperimentUser`"
setenv ExperimentUser $get
if ($ExperimentUser == None) then
  setenv ExperimentUser ${USER}
endif

# ExperimentName
set get = "`$getLocalOrNone ExperimentName`"
setenv ExperimentName $get

# ExpSuffix
$setLocal ExpSuffix

## ParentDirectory
# where this experiment is located
setenv ParentDirectory ${ParentDirectoryPrefix}/${ExperimentUser}/${ParentDirectorySuffix}

## experiment name
if ($ExperimentName == None) then
  # derive experiment title parts from critical config elements
  #(1) DAType
  set ExpBase = ${DAType}

  #(2) ensemble-related settings
  set ExpEnsSuffix = ''
  if ($nEnsDAMembers > 1) then
    set ExpBase = eda_${ExpBase}
    if ($EDASize > 1) then
      set ExpEnsSuffix = '_NMEM'${nDAInstances}x${EDASize}
      if ($MinimizerAlgorithm == $BlockEDA) then
        set ExpEnsSuffix = ${ExpEnsSuffix}Block
      endif
    else
      set ExpEnsSuffix = '_NMEM'${nEnsDAMembers}
    endif
    if (${rtpp__relaxationFactor} != "0.0") set ExpEnsSuffix = ${ExpEnsSuffix}_RTPP${rtpp__relaxationFactor}
    if (${LeaveOneOutEDA} == True) set ExpEnsSuffix = ${ExpEnsSuffix}_LeaveOneOut
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
setenv ExperimentName ${ExperimentUser}_${ExperimentName}
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
setenv ParentDirectory ${ParentDirectory}
setenv ExperimentName ${ExperimentName}
setenv ExperimentDirectory ${ExperimentDirectory}
setenv PackageBaseName ${PackageBaseName}
setenv mainScriptDir ${mainScriptDir}
setenv ConfigDir ${mainScriptDir}/config
setenv ModelConfigDir ${mainScriptDir}/config/mpas
setenv nEnsDAMembers ${nEnsDAMembers}
EOF

