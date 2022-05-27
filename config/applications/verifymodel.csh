#!/bin/csh -f

if ( $?config_verifymodel ) exit 0
setenv config_verifymodel 1

source config/model.csh
source config/experiment.csh
source config/scenario.csh verifymodel setNestedVerifyModel

$setLocal pyVerifyDir

## job
$setLocal job.${outerMesh}.baseSeconds
setenv verifymodel__seconds $baseSeconds

$setLocal job.${outerMesh}.secondsPerEDAMember
@ seconds = $secondsPerEDAMember * $nMembers + $baseSeconds
setenv verifymodelens__seconds $seconds
