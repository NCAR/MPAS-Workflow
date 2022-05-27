#!/bin/csh -f

if ( $?config_forecast ) exit 0
setenv config_forecast 1

source config/model.csh
source config/workflow.csh
source config/scenario.csh forecast setNestedForecast

set mesh = "$outerMesh"
setenv nCells "$nCellsOuter"

$setLocal updateSea

setenv AppName forecast

## job
$setLocal job.${mesh}.baseSeconds
$setLocal job.${mesh}.secondsPerForecastHR

@ seconds = $secondsPerForecastHR * $CyclingWindowHR + $baseSeconds
setenv forecast__seconds $seconds

@ seconds = $secondsPerForecastHR * $ExtendedFCWindowHR + $baseSeconds
setenv extendedforecast__seconds $seconds

$setNestedForecast job.${mesh}.nodes
$setNestedForecast job.${mesh}.PEPerNode
