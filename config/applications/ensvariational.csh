#!/bin/csh -f

if ( $?config_ensvariational ) exit 0
setenv config_ensvariational 1

source config/scenario.csh
source config/model.csh
source config/applications/variational.csh

# setLocal is a helper function that picks out a configuration node
# under the "ensvariational" key of scenarioConfig
setenv baseConfig scenarios/base/ensvariational.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig ensvariational"
setenv setNestedEnsOfVariational "source $setNestedConfig $baseConfig $scenarioConfig ensvariational"

#job
$setLocal job.${outerMesh}.baseSeconds
$setLocal job.${outerMesh}.secondsPerEnVarMember

@ seconds = $secondsPerEnVarMember * $nEnVarMembers + $baseSeconds
setenv ensvariational__seconds $seconds

$setLocal job.${outerMesh}.nodesPerMember
@ nodes = $nodesPerMember * $EDASize
setenv ensvariational__nodes $nodes
$setNestedEnsOfVariational job.${outerMesh}.PEPerNode
$setNestedEnsOfVariational job.${outerMesh}.memory
