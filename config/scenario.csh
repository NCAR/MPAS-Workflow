#!/bin/csh -f

if ( $?config_scenario ) exit 0
setenv config_scenario 1

source config/environmentPython.csh

## scenario
# select from pre-defined scenarios or define your own
# canned options:
# + 3dvar_OIE120km_WarmStart
# + 3dvar_OIE120km_ColdStart
# + 3denvar_OIE120km_WarmStart
# + eda_OIE120km_WarmStart
# + 3denvar_O30kmIE60km_WarmStart

setenv scenario 3dvar_OIE120km_WarmStart

# The selected scenario should be described in a yaml file in the config/scenarios directory.  Only the
# options that differ from the defaults need to be included in the scenario yaml, but other options
# may also be included for clarity.

## config tools
source config/config.csh

## directory where config is located
set scenarioDirectory = scenarios

## default config
setenv baseConfig ${scenarioDirectory}/baseConfig.yaml

## this config
setenv scenarioConfig ${scenarioDirectory}/${scenario}.yaml
