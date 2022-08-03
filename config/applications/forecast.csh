#!/bin/csh -f

# ArgMesh: str, mesh, one of allMeshesJinja
set ArgMesh = "$1"

#if ( $?config_forecast ) exit 0
#set config_forecast = 1

source config/model.csh
source config/workflow.csh
source config/scenario.csh forecast

$setLocal updateSea

## IAU
$setNestedForecast IAU
if ($forecast__IAU == True) then
  @ IAUoutIntervalHR = $CyclingWindowHR / 2
  @ IAUfcLengthHR = 3 * $IAUoutIntervalHR
  setenv FCLengthHR $IAUfcLengthHR
  setenv FCOutIntervalHR $IAUoutIntervalHR
else
  setenv FCLengthHR $CyclingWindowHR
  setenv FCOutIntervalHR $CyclingWindowHR
endif
##

setenv AppName forecast

## job
$setLocal job.${ArgMesh}.baseSeconds
$setLocal job.${ArgMesh}.secondsPerForecastHR

@ seconds = $secondsPerForecastHR * $CyclingWindowHR + $baseSeconds
setenv forecast__seconds $seconds

@ seconds = $secondsPerForecastHR * $ExtendedFCLengthHR + $baseSeconds
setenv extendedforecast__seconds $seconds

$setNestedForecast job.${ArgMesh}.nodes
$setNestedForecast job.${ArgMesh}.PEPerNode
