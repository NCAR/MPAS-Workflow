#!/bin/csh -f

if ( $?config_initic ) exit 0
setenv config_initic 1

source config/scenario.csh
source config/model.csh

# setLocal is a helper function that picks out a configuration node
# under the "initic" key of scenarioConfig
setenv baseConfig scenarios/base/initic.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig initic"
setenv setNestedInitIC "source $setNestedConfig $baseConfig $scenarioConfig initic"

setenv AppName initic

## job
$setNestedInitIC job.${outerMesh}.seconds
$setNestedInitIC job.${outerMesh}.nodes
$setNestedInitIC job.${outerMesh}.PEPerNode
