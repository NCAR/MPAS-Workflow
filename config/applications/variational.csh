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

## variational settings
$setLocal DAType

$setLocal nInnerIterations
# nOuterIterations, automatically determined from length of nInnerIterations
setenv nOuterIterations ${#nInnerIterations}

# localization
if ($DAType == 3denvar || $DAType == 3dhybrid) then
  $setLocal localization.${ensembleMesh}.bumpLocPrefix
  $setLocal localization.${ensembleMesh}.bumpLocDir
endif

# covariance
if ($DAType == 3dvar || $DAType == 3dhybrid) then
  $setLocal covariance.bumpCovControlVariables
  $setLocal covariance.bumpCovPrefix
  $setLocal covariance.bumpCovVBalPrefix
  $setLocal covariance.${innerMesh}.bumpCovDir
  $setLocal covariance.${innerMesh}.bumpCovStdDevFile
  $setLocal covariance.${innerMesh}.bumpCovVBalDir
endif

set ensembleCovarianceWeight = "`$getLocalOrNone ensembleCovarianceWeight`"
set staticCovarianceWeight = "`$getLocalOrNone staticCovarianceWeight`"

# stochastic settings
set EDASize = "`$getLocalOrNone EDASize`"
if ($EDASize == None) then
  set EDASize = 1
endif
set nDAInstances = "`$getLocalOrNone nDAInstances`"
if ($nDAInstances == None) then
  set nDAInstances = 1
endif
$setLocal SelfExclusion

# nEnsDAMembers is the total number of ensemble DA members, product of EDASize and nDAInstances
# Should be in range (1, $firstEnsFCNMembers); affects data source in config/modeldata.csh
@ nEnsDAMembers = $EDASize * $nDAInstances
setenv nEnsDAMembers $nEnsDAMembers

# ensemble inflation settings
$setLocal ABEInflation
$setLocal ABEIChannel

## required settings for PrepJEDI.csh
setenv AppName $DAType
setenv appyaml ${AppName}.yaml

# observations, automatically combine two parent ObsList's
$setLocal benchmarkObservations
$setLocal experimentalObservations
set observations = ($benchmarkObservations $experimentalObservations)

set MeshList = (Outer Inner)
set nCellsList = ($nCellsOuter $nCellsInner)
set localStaticFieldsFileList = ( \
$localStaticFieldsFileOuter \
$localStaticFieldsFileInner \
)
set StreamsFileList = ($outerStreamsFile $innerStreamsFile)
set NamelistFileList = ($outerNamelistFile $innerNamelistFile)
$setLocal nObsIndent
$setLocal radianceThinningDistance
$setLocal biasCorrection
$setLocal tropprsMethod
$setLocal maxIODAPoolSize

## clean
$setLocal retainObsFeedback

## job
## nEnVarMembers (int)
# ensemble size for "envar" applications; only used for job timings
if ($DAType == 3dvar) then
  setenv nEnVarMembers 0
else
  if ($nEnsDAMembers > 1) then
    setenv nEnVarMembers $nEnsDAMembers
  else
    setenv nEnVarMembers $nPreviousEnsDAMembers
  endif
endif

$setLocal job.${outerMesh}.${innerMesh}.$DAType.baseSeconds
set secondsPerEnVarMember = "`$getLocalOrNone job.${outerMesh}.${innerMesh}.$DAType.secondsPerEnVarMember`"
if ("$secondsPerEnVarMember" == None) then
  set secondsPerEnVarMember = 0
endif
@ seconds = $secondsPerEnVarMember * $nEnVarMembers + $baseSeconds
setenv variational__seconds $seconds

$setNestedVariational job.${outerMesh}.${innerMesh}.$DAType.nodes
$setNestedVariational job.${outerMesh}.${innerMesh}.$DAType.PEPerNode
$setNestedVariational job.${outerMesh}.${innerMesh}.$DAType.memory

##############################
## more non-YAML-fied settings
##############################
## MinimizerAlgorithm
# OPTIONS: DRIPCG, DRPLanczos, DRPBlockLanczos
# see classes derived from oops/src/oops/assimilation/Minimizer.h for all options
# Notes about DRPBlockLanczos:
# + still experimental, and not reliable for this experiment
# + only available when EDASize > 1
setenv BlockEDA DRPBlockLanczos
setenv MinimizerAlgorithm DRIPCG

if ($EDASize == 1 && $MinimizerAlgorithm == $BlockEDA) then
  echo "WARNING: MinimizerAlgorithm cannot be $BlockEDA when EDASize is 1, re-setting to DRPLanczos"
  setenv MinimizerAlgorithm DRPLanczos
endif

setenv YAMLPrefix ${AppName}_
