#!/bin/csh -f

# only load hofx if it is not already loaded
# note: set must be used instead of setenv, because some of the setLocal commands apply to
# lists, which use set instead of setenv
if ( $?config_hofx ) exit 0
set config_hofx = 1

source config/scenario.csh

# setLocal is a helper function that picks out a configuration node
# under the "hofx" key of scenarioConfig
setenv baseConfig scenarios/base/hofx.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig hofx"

$setLocal observations
$setLocal nObsIndent
$setLocal DirsYamlBase
$setLocal DirsYamlBiasFilters
