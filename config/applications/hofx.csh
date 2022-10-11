#!/bin/csh -f

# only load hofx if it is not already loaded
# note: set must be used instead of setenv, because some of the setLocal commands apply to
# lists, which use set instead of setenv
if ( $?config_hofx ) exit 0
set config_hofx = 1

source config/model.csh
source config/scenario.csh hofx

## required settings for PrepJEDI.csh
$setLocal observations

setenv AppName hofx
setenv appyaml ${AppName}.yaml

set MeshList = (HofX)
set nCellsList = ($nCellsOuter)
set StreamsFileList = ($outerStreamsFile)
set NamelistFileList = ($outerNamelistFile)

$setLocal nObsIndent

$setLocal biasCorrection
$setLocal radianceThinningDistance
$setLocal tropprsMethod
$setLocal maxIODAPoolSize

$setLocal removeThinnedObs
$setLocal observationsToThinning

## clean
$setLocal retainObsFeedback

## job
$setNestedHofx job.${outerMesh}.seconds
$setNestedHofx job.${outerMesh}.nodes
$setNestedHofx job.${outerMesh}.PEPerNode
$setNestedHofx job.${outerMesh}.memory

## jobqc
$setNestedHofx jobqc.${outerMesh}.secondsqc
$setNestedHofx jobqc.${outerMesh}.nodesqc
$setNestedHofx jobqc.${outerMesh}.PEPerNodeqc
$setNestedHofx jobqc.${outerMesh}.memoryqc
