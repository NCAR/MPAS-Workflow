#!/bin/csh -f

if ( $?config_scenario ) exit 0
setenv config_scenario 1

## python environment
source config/environmentPython.csh

## config tools
source config/config.csh

# The scenario must be described in a yaml file in the scenarioDirectory.  Only the options that
# differ from the defaults in baseConfig need to be included in the scenario yaml, but other
# options may also be included for clarity.

## directory where config is located
set scenarioDirectory = scenarios

## scenario
# select from pre-defined scenarios or define your own
# canned options:
# + 3dvar_OIE120km_WarmStart
# + 3dvar_OIE120km_ColdStart
# + 3denvar_OIE120km_WarmStart
# + eda_OIE120km_WarmStart
# + 3denvar_O30kmIE60km_WarmStart

set primaryScenario = 3dvar_OIE120km_WarmStart
#TODO: enable concatenation of multiple config files together for mixing and matching
# of, e.g., observation data source for the same primaryScenario.  Potentially this requires a
# baseConfig for each component of scenarioParts.
#set observationScenario = PANDACArchives
#set observationScenario = GladeRDAOnline
#set observationScenario = GFSFTPOnline
#set scenarioParts = (/
#  $observationScenario
#)
#set thisScenario = thisConfig
#cat ${scenarioDirectory}/$primaryScenario.yaml > ${scenarioDirectory}/$thisScenario.yaml
#foreach scenario ($scenarioParts)
#  cat scenarios/$scenario.yaml >> ${scenarioDirectory}/$thisScenario.yaml
#end

set thisScenario = $primaryScenario

## default config
setenv baseConfig ${scenarioDirectory}/baseConfig.yaml

## this config
setenv scenarioConfig ${scenarioDirectory}/${thisScenario}.yaml
