#!/bin/csh -f

if ( $?config_forecast ) exit 0
setenv config_forecast 1

source config/scenario.csh
source config/model.csh
source config/workflow.csh

# setLocal is a helper function that picks out a configuration node
# under the "forecast" key of scenarioConfig
setenv baseConfig scenarios/base/forecast.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig forecast"
setenv setNestedForecast "source $setNestedConfig $baseConfig $scenarioConfig forecast"

set mesh = "$outerMesh"
setenv nCells "$nCellsOuter"

$setLocal updateSea

setenv AppMPASConfigDir config/mpas/forecast

## job
$setLocal job.${mesh}.baseSeconds
$setLocal job.${mesh}.secondsPerForecastHR

@ seconds = $secondsPerForecastHR * $CyclingWindowHR + $baseSeconds
setenv forecast__seconds $seconds

@ seconds = $secondsPerForecastHR * $ExtendedFCWindowHR + $baseSeconds
setenv extendedforecast__seconds $seconds

$setNestedForecast job.${mesh}.nodes
$setNestedForecast job.${mesh}.PEPerNode
