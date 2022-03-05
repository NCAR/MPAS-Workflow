#!/bin/csh -f

if ( $?config_scenario ) exit 0
setenv config_scenario 1

## python environment
source config/environmentPython.csh

## config tools
source config/config.csh

# The scenario must be described in a yaml file in the scenarioDirectory.  Options that differ
# from the defaults in scenarios/base/*.yaml MUST be included in the scenario yaml, and other
# options may also be included as desired for clarity.

## directory where config is located
set scenarioDirectory = scenarios

## scenario
# select from pre-defined scenarios or define your own
# canned options:
# + 3dvar_OIE120km_WarmStart
# + 3dvar_OIE120km_ColdStart
# + 3denvar_OIE120km_WarmStart
# + 3denvar_O30kmIE60km_WarmStart
# + 3denvar_O30kmIE60km_WarmStart_ABEI
# + 3dhybrid_OIE120km_WarmStart (experimental)
# + eda_OIE120km_WarmStart
# + eda_OIE60km_WarmStart (experimental)

set scenario = 3dvar_OIE120km_WarmStart

## this config
setenv scenarioConfig ${scenarioDirectory}/${scenario}.yaml

#TODO: possibly implement one of below options to reduce config overhead
# (1) create a combined yaml (thisConfig) to avoid double-reading of baseConfig and
#     scenarioConfig [less impactful]
# (2) parse each sub-section of the yaml into environment variables, e.g.,
#     __workflow__VARIABLENAME, to avoid many redundant reads of the entire config
#     [more impactful, added complexity]
# (3) move full config parsing (and task scripts?) into python [most work]
