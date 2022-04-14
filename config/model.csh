#!/bin/csh -f

# only load model if it is not already loaded
if ( $?config_model ) exit 0
setenv config_model 1

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "model" key of scenarioConfig
setenv baseConfig scenarios/base/model.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig model"
setenv setNestedModel "source $setNestedConfig $baseConfig $scenarioConfig model"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig model"

$setNestedModel AnalysisSource
$setLocal outerMesh
$setLocal innerMesh
$setLocal ensembleMesh

setenv MeshesDescriptor O
if ("$outerMesh" != "$innerMesh") then
  setenv MeshesDescriptors ${MeshesDescriptor}${outerMesh}
endif
setenv MeshesDescriptors ${MeshesDescriptor}IE${innerMesh}

if ("$innerMesh" != "$ensembleMesh") then
  #TODO: remove when this is no longer a limitation
  echo "$0 (ERROR): innerMesh ($innerMesh) must equal ensembleMesh($ensembleMesh)"
  exit 1
endif

setenv nCellsOuter "`$getLocalOrNone nCells.$outerMesh`"
setenv nCellsInner "`$getLocalOrNone nCells.$innerMesh`"
setenv nCellsEnsemble "`$getLocalOrNone nCells.$ensembleMesh`"

$setLocal GraphInfoDir

$setNestedModel precision
