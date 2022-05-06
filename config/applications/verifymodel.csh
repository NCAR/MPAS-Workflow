#!/bin/csh -f

if ( $?config_verifymodel ) exit 0
setenv config_verifymodel 1

source config/scenario.csh
source config/model.csh
source config/experiment.csh

# setLocal is a helper function that picks out a configuration node
# under the "verifymodel" key of scenarioConfig
setenv baseConfig scenarios/base/verifymodel.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig verifymodel"

$setLocal pyVerifyDir

## job
$setLocal job.${outerMesh}.baseSeconds
setenv verifymodel__seconds $baseSeconds

$setLocal job.${outerMesh}.secondsPerEDAMember
@ seconds = $secondsPerEDAMember * $nMembers + $baseSeconds
setenv verifymodelens__seconds $seconds
