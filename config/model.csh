#!/bin/csh -f

# only load model if it is not already loaded
if ( $?config_model ) exit 0
setenv config_model 1

source config/scenario.csh
source config/variational.csh

# setLocal is a helper function that picks out a configuration node
# under the "model" key of scenarioConfig
setenv baseConfig scenarios/base/model.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig model"
setenv setNestedModel "source $setNestedConfig $baseConfig $scenarioConfig model"

$setNestedModel AnalysisSource
$setLocal MPASGridDescriptor
$setLocal GraphInfoDir
