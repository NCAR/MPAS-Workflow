#!/bin/csh -f

if ( $?config_rtpp ) exit 0
setenv config_rtpp 1

source config/scenario.csh
source config/model.csh
source config/firstbackground.csh

# setLocal is a helper function that picks out a configuration node
# under the "rtpp" key of scenarioConfig
setenv baseConfig scenarios/base/rtpp.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig rtpp"
setenv setNestedRTPP "source $setNestedConfig $baseConfig $scenarioConfig rtpp"

$setNestedRTPP relaxationFactor
$setLocal retainOriginalAnalyses

setenv AppName rtpp
setenv appyaml ${AppName}.yaml

## job
$setLocal job.${ensembleMesh}.baseSeconds
$setLocal job.${ensembleMesh}.secondsPerMember

@ seconds = $secondsPerMember * $nMembers + $baseSeconds
setenv rtpp__seconds $seconds

$setNestedRTPP job.${ensembleMesh}.nodes
$setNestedRTPP job.${ensembleMesh}.PEPerNode
$setNestedRTPP job.${ensembleMesh}.memory
