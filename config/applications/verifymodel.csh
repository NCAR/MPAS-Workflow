#!/bin/csh -f

if ( $?config_verifymodel ) exit 0
setenv config_verifymodel 1

source config/model.csh
source config/experiment.csh
source config/scenario.csh verifymodel

$setLocal pyVerifyDir

## job
$setLocal job.${outerMesh}.baseSeconds
setenv verifymodel__seconds $baseSeconds

$setLocal job.${outerMesh}.secondsPerMember
@ seconds = $secondsPerMember * $nMembers + $baseSeconds
setenv verifymodelens__seconds $seconds
