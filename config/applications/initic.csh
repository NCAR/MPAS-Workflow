#!/bin/csh -f

if ( $?config_initic ) exit 0
setenv config_initic 1

source config/model.csh
source config/scenario.csh initic

setenv AppName initic

## job
$setNestedInitic job.${outerMesh}.seconds
$setNestedInitic job.${outerMesh}.nodes
$setNestedInitic job.${outerMesh}.PEPerNode
