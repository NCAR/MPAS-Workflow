#!/bin/csh -f

if ( $?config_rtpp ) exit 0
setenv config_rtpp 1

source config/model.csh
source config/applications/variational.csh
source config/scenario.csh rtpp

$setNestedRtpp relaxationFactor
$setLocal retainOriginalAnalyses

setenv AppName rtpp
setenv appyaml ${AppName}.yaml

## job
$setLocal job.${ensembleMesh}.baseSeconds
$setLocal job.${ensembleMesh}.secondsPerEDAMember

@ seconds = $secondsPerEDAMember * $nEnsDAMembers + $baseSeconds
setenv rtpp__seconds $seconds

$setNestedRtpp job.${ensembleMesh}.nodes
$setNestedRtpp job.${ensembleMesh}.PEPerNode
$setNestedRtpp job.${ensembleMesh}.memory
