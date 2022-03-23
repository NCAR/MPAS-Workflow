#!/bin/csh -f

# only load variational if it is not already loaded
# note: set must be used instead of setenv, because some of the setLocal commands apply to
# lists, which use set instead of setenv
if ( $?config_variational ) exit 0
set config_variational = 1

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "variational" key of scenarioConfig
setenv baseConfig scenarios/base/variational.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig variational"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig variational"

$setLocal DAType

set ensembleCovarianceWeight = "`$getLocalOrNone ensembleCovarianceWeight`"
set staticCovarianceWeight = "`$getLocalOrNone staticCovarianceWeight`"

$setLocal nInnerIterations
# nOuterIterations, automatically determined from length of nInnerIterations
setenv nOuterIterations ${#nInnerIterations}

set satelliteBias = "`$getLocalOrNone satelliteBias`"

$setLocal benchmarkObservations
$setLocal experimentalObservations
# observations, automatically combine two parent ObsList's
set observations = ($benchmarkObservations $experimentalObservations)
$setLocal nObsIndent

# deterministic settings
$setLocal fixedEnsBType
$setLocal nPreviousEnsDAMembers
$setLocal PreviousEDAForecastDir

# stochastic settings
set EDASize = "`$getLocalOrNone EDASize`"
if ($EDASize == None) then
  set EDASize = 1
endif
set nDAInstances = "`$getLocalOrNone nDAInstances`"
if ($nDAInstances == None) then
  set nDAInstances = 1
endif

$setLocal LeaveOneOutEDA
$setLocal RTPPInflationFactor
$setLocal storeOriginalRTPPAnalyses

# ensemble inflation settings
$setLocal ABEInflation
$setLocal ABEIChannel

#########################
## non-YAML-fied settings
#########################
## MinimizerAlgorithm
# OPTIONS: DRIPCG, DRPLanczos, DRPBlockLanczos
# see classes derived from oops/src/oops/assimilation/Minimizer.h for all options
# Notes about DRPBlockLanczos:
# + still experimental, and not reliable for this experiment
# + only available when EDASize > 1
setenv BlockEDA DRPBlockLanczos
setenv MinimizerAlgorithm DRIPCG

## nEnsDAMembers
# total number of ensemble DA members, product of EDASize and nDAInstances
# Should be in range (1, $firstEnsFCNMembers), depends on data source in config/modeldata.csh
@ nEnsDAMembers = $EDASize * $nDAInstances
setenv nEnsDAMembers $nEnsDAMembers

if ($EDASize == 1 && $MinimizerAlgorithm == $BlockEDA) then
  echo "WARNING: MinimizerAlgorithm cannot be $BlockEDA when EDASize is 1, re-setting to DRPLanczos"
  setenv MinimizerAlgorithm DRPLanczos
endif

setenv variationalYAMLPrefix variational_

# VARBC
$setLocal initialVARBCtable
