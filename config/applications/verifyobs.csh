#!/bin/csh -f

if ( $?config_verifyobs ) exit 0
setenv config_verifyobs 1

source config/scenario.csh
source config/applications/variational.csh

# setLocal is a helper function that picks out a configuration node
# under the "verifyobs" key of scenarioConfig
setenv baseConfig scenarios/base/verifyobs.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig verifyobs"

#job
$setLocal job.baseSeconds
setenv verifyobs__seconds $baseSeconds

$setLocal job.secondsPerEDAMember
@ seconds = $secondsPerEDAMember * $nEnsDAMembers + $baseSeconds
setenv verifyobsens__seconds $seconds
