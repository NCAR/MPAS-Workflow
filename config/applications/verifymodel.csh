#!/bin/csh -f

if ( $?config_verifymodel ) exit 0
setenv config_verifymodel 1

source config/scenario.csh
source config/model.csh
source config/applications/variational.csh

# setLocal is a helper function that picks out a configuration node
# under the "verifymodel" key of scenarioConfig
setenv baseConfig scenarios/base/verifymodel.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig verifymodel"

#job
$setLocal job.${outerMesh}.baseSeconds
$setLocal job.${outerMesh}.secondsPerEDAMember

setenv verifymodel__seconds $baseSeconds

@ seconds = $secondsPerEDAMember*$nEnsDAMembers + $baseSeconds
setenv verifymodelens__seconds $seconds
