#!/bin/csh -f

if ( $?config_initic ) exit 0
setenv config_initic 1

source config/model.csh
source config/scenario.csh initic setNestedInitIC

setenv AppName initic

## job
$setNestedInitIC job.${outerMesh}.seconds
$setNestedInitIC job.${outerMesh}.nodes
$setNestedInitIC job.${outerMesh}.PEPerNode
