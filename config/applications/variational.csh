#!/bin/csh -f

# only load variational if it is not already loaded
# note: set must be used instead of setenv, because some of the setLocal commands apply to
# lists, which use set instead of setenv
if ( $?config_variational ) exit 0
set config_variational = 1

source config/scenario.csh
source config/model.csh

# setLocal is a helper function that picks out a configuration node
# under the "variational" key of scenarioConfig
setenv baseConfig scenarios/base/variational.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig variational"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig variational"
setenv setNestedVariational "source $setNestedConfig $baseConfig $scenarioConfig variational"

$setLocal DAType

set ensembleCovarianceWeight = "`$getLocalOrNone ensembleCovarianceWeight`"
set staticCovarianceWeight = "`$getLocalOrNone staticCovarianceWeight`"

$setLocal nInnerIterations
# nOuterIterations, automatically determined from length of nInnerIterations
setenv nOuterIterations ${#nInnerIterations}


$setLocal benchmarkObservations
$setLocal experimentalObservations
# observations, automatically combine two parent ObsList's
set observations = ($benchmarkObservations $experimentalObservations)
$setLocal nObsIndent
$setLocal radianceThinningDistance

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

$setLocal biasCorrection

$setLocal retainObsFeedback


# TODO: determine job settings for 3dhybrid; for now use 3denvar settings for non-3dvar DAType's
set baseDAType = 3denvar
if ( "$DAType" =~ *"3dvar"* ) then
  set baseDAType = 3dvar
else if ( "$DAType" =~ *"3denvar"* ) then
  set baseDAType = 3denvar
else if ( "$DAType" =~ *"3dhybrid"* ) then
  set baseDAType = 3dhybrid
endif

# localization
if ($baseDAType == 3denvar || $baseDAType == 3dhybrid) then
  $setLocal localization.${ensembleMesh}.bumpLocPrefix
  $setLocal localization.${ensembleMesh}.bumpLocDir
endif

# covariance
if ($baseDAType == 3dvar || $baseDAType == 3dhybrid) then
  $setLocal covariance.bumpCovControlVariables
  $setLocal covariance.bumpCovPrefix
  $setLocal covariance.bumpCovVBalPrefix
  $setLocal covariance.${innerMesh}.bumpCovDir
  $setLocal covariance.${innerMesh}.bumpCovStdDevFile
  $setLocal covariance.${innerMesh}.bumpCovVBalDir
endif

# job
## nEnVarMembers
# OPTIONS: integer
# ensemble size for "envar" applications; only used for job timings
# defaults to 20 for GEFS-ensemble retrospective experiments
setenv nEnVarMembers 20
if ($nEnsDAMembers > 1) then
  setenv nEnVarMembers $nEnsDAMembers
endif
if ($baseDAType == 3dvar) then
  setenv nEnVarMembers 0
  #TODO: add extra time/memory for covariance multiplication
endif

$setLocal job.${outerMesh}.${innerMesh}.$baseDAType.baseSeconds
set secondsPerEnVarMember = "`$getLocalOrNone job.${outerMesh}.${innerMesh}.$baseDAType.secondsPerEnVarMember`"
if ("$secondsPerEnVarMember" == None) then
  set secondsPerEnVarMember = 0
endif
@ seconds = $secondsPerEnVarMember * $nEnVarMembers + $baseSeconds
setenv variational__seconds $seconds

$setNestedVariational job.${outerMesh}.${innerMesh}.$baseDAType.nodes
$setNestedVariational job.${outerMesh}.${innerMesh}.$baseDAType.PEPerNode
$setNestedVariational job.${outerMesh}.${innerMesh}.$baseDAType.memory
