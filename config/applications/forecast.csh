#!/bin/csh -f

# ArgMesh: str, mesh, one of allMeshesJinja
set ArgMesh = "$1"

if ( $?config_forecast ) exit 0
setenv config_forecast 1

source config/model.csh
source config/workflow.csh
source config/scenario.csh forecast

$setLocal updateSea

setenv AppName forecast

## job
$setLocal job.${ArgMesh}.baseSeconds
$setLocal job.${ArgMesh}.secondsPerForecastHR

@ seconds = $secondsPerForecastHR * $CyclingWindowHR + $baseSeconds
setenv forecast__seconds $seconds

@ seconds = $secondsPerForecastHR * $ExtendedFCWindowHR + $baseSeconds
setenv extendedforecast__seconds $seconds

$setNestedForecast job.${ArgMesh}.nodes
$setNestedForecast job.${ArgMesh}.PEPerNode
