#!/bin/csh -f

if ( $?config_scenario ) exit 0
setenv config_scenario 1

source config/environmentPython.csh

## scenario
# select from pre-defined scenarios or define your own
# canned options:
# + WarmStart_OIE120km_3dvar
# + WarmStart_OIE120km_3denvar
# + WarmStart_OIE120km_eda_3denvar
# + WarmStart_O30kmIE60km_3denvar
# + ColdStart_2018041418_OIE120km_3dvar

setenv scenario WarmStart_OIE120km_3dvar

# The selected scenario should be described in a yaml file in the config/scenarios directory.  Only the
# options that differ from the defaults need to be included in the scenario yaml, but other options
# may also be included for clarity.

## config tools
source config/config.csh

## default config
setenv baseConfig scenarios/baseConfig.yaml

## this config
setenv scenarioConfig scenarios/${scenario}.yaml
