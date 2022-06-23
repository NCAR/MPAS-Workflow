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
$setLocal job.${mesh}.baseSeconds
$setLocal job.${mesh}.secondsPerForecastHR

@ seconds = $secondsPerForecastHR * $CyclingWindowHR + $baseSeconds
setenv forecast__seconds $seconds

@ seconds = $secondsPerForecastHR * $ExtendedFCLengthHR + $baseSeconds
setenv extendedforecast__seconds $seconds

$setNestedForecast job.${mesh}.nodes
$setNestedForecast job.${mesh}.PEPerNode
