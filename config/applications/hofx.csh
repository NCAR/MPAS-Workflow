#!/bin/csh -f

# only load hofx if it is not already loaded
# note: set must be used instead of setenv, because some of the setLocal commands apply to
# lists, which use set instead of setenv
if ( $?config_hofx ) exit 0
set config_hofx = 1

source config/scenario.csh
source config/model.csh

# setLocal is a helper function that picks out a configuration node
# under the "hofx" key of scenarioConfig
setenv baseConfig scenarios/base/hofx.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig hofx"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig hofx"
setenv setNestedHofX "source $setNestedConfig $baseConfig $scenarioConfig hofx"

## required settings for PrepJEDI.csh
$setLocal observations

setenv AppName hofx
setenv appyaml ${AppName}.yaml

set MeshList = (HofX)
set nCellsList = ($nCellsOuter)
set StreamsFileList = ($outerStreamsFile)
set NamelistFileList = ($outerNamelistFile)

$setLocal nObsIndent

$setLocal biasCorrection
$setLocal radianceThinningDistance
$setLocal tropprsMethod

## clean
$setLocal retainObsFeedback

## job
$setNestedHofX job.${outerMesh}.seconds
$setNestedHofX job.${outerMesh}.nodes
$setNestedHofX job.${outerMesh}.PEPerNode
$setNestedHofX job.${outerMesh}.memory
