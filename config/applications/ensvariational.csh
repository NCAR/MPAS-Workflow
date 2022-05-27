#!/bin/csh -f

if ( $?config_ensvariational ) exit 0
setenv config_ensvariational 1

source config/model.csh
source config/applications/variational.csh
source config/scenario.csh ensvariational setNestedEnsOfVariational

## job
$setLocal job.${outerMesh}.baseSeconds
$setLocal job.${outerMesh}.secondsPerEnVarMember

@ seconds = $secondsPerEnVarMember * $nEnVarMembers + $baseSeconds
setenv ensvariational__seconds $seconds

$setLocal job.${outerMesh}.nodesPerMember
@ nodes = $nodesPerMember * $EDASize
setenv ensvariational__nodes $nodes
$setNestedEnsOfVariational job.${outerMesh}.PEPerNode
$setNestedEnsOfVariational job.${outerMesh}.memory
