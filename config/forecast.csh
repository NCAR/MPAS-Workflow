#!/bin/csh -f

# only load forecast if it is not already loaded
# note: set must be used instead of setenv, because some of the setLocal commands apply to
# lists, which use set instead of setenv
if ( $?config_forecast ) exit 0
set config_forecast = 1

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "forecast" key of scenarioConfig
setenv baseConfig scenarios/base/forecast.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig forecast"
setenv setNestedForecast "source $setNestedConfig $baseConfig $scenarioConfig forecast"

$setLocal updateSea
$setNestedForecast precision
