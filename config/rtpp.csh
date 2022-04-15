#!/bin/csh -f

if ( $?config_rtpp ) exit 0
setenv config_rtpp 1

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "rtpp" key of scenarioConfig
setenv baseConfig scenarios/base/rtpp.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig rtpp"
setenv setNestedRTPP "source $setNestedConfig $baseConfig $scenarioConfig rtpp"

$setNestedRTPP relaxationFactor
$setLocal retainOriginalAnalyses
