#!/bin/csh -f

if ( $?config_verifyobs ) exit 0
setenv config_verifyobs 1

source config/experiment.csh
source config/scenario.csh verifyobs

$setLocal pyVerifyDir

## job
$setLocal job.baseSeconds
setenv verifyobs__seconds $baseSeconds

$setLocal job.secondsPerMember
@ seconds = $secondsPerMember * $nMembers + $baseSeconds
setenv verifyobsens__seconds $seconds
