#!/bin/csh -f

if ( $?config_experiment ) exit 0
setenv config_experiment 1

source config/workflow.csh
source config/variational.csh
source config/model.csh

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "experiment" key of scenarioConfig
setenv baseConfig scenarios/base/experiment.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig experiment"

$setLocal ExpSuffix
$setLocal ExperimentName
$setLocal ParentDirectoryPrefix
$setLocal ExperimentUser
$setLocal ParentDirectorySuffix

if ($ExperimentUser == DEFAULT) then
  setenv ExperimentUser ${USER}
endif

# ParentDirectory, where all experiments are located
# TODO: move to a higher level config file so that benchmark.csh can use it too
# TODO: replace "/glade/scratch", "${USER}", and "pandac" with a user-configurable directory
setenv ParentDirectory ${ParentDirectoryPrefix}/${ExperimentUser}/${ParentDirectorySuffix}

## experiment name
if ($ExperimentName == DEFAULT) then
  # derive experiment title parts from critical config elements
  setenv ExperimentName ${DAType}

  #(1) inner iteration counts
  set ExpIterSuffix = ''
  foreach nInner ($nInnerIterations)
    set ExpIterSuffix = ${ExpIterSuffix}-${nInner}
  end
  if ( $nOuterIterations > 0 ) then
    set ExpIterSuffix = ${ExpIterSuffix}-iter
  endif
  setenv ExperimentName ${ExperimentName}${ExpIterSuffix}

  #(2) observation selection
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
  setenv ExperimentName ${ExperimentName}${ExpObsSuffix}

  #(3) ensemble-related settings
  set ExpEnsSuffix = ''
  if ($nEnsDAMembers > 1) then
    if ($EDASize > 1) then
      set ExpEnsSuffix = '_NMEM'${nDAInstances}x${EDASize}
      if ($MinimizerAlgorithm == $BlockEDA) then
        set ExpEnsSuffix = ${ExpEnsSuffix}Block
      endif
    else
      set ExpEnsSuffix = '_NMEM'${nEnsDAMembers}
    endif
    if (${RTPPInflationFactor} != "0.0") set ExpEnsSuffix = ${ExpEnsSuffix}_RTPP${RTPPInflationFactor}
    if (${LeaveOneOutEDA} == True) set ExpEnsSuffix = ${ExpEnsSuffix}_LeaveOneOut
    if (${ABEInflation} == True) set ExpEnsSuffix = ${ExpEnsSuffix}_ABEI_BT${ABEIChannel}
  endif
  setenv ExperimentName ${ExperimentName}${ExpEnsSuffix}
  setenv ExperimentName ${ExperimentName}_${MPASGridDescriptor}
  setenv ExperimentName ${ExperimentName}_${InitializationType}
endif
setenv ExperimentName ${ExperimentUser}_${ExperimentName}
setenv ExperimentName ${ExperimentName}${ExpSuffix}
