#!/bin/csh -f

#if ( $?config_scenario ) exit 0
#set config_scenario = 1

# This script sets up the environment needed to parse a particular section of the
# complete scenario configuration YAML.

# It should be sourced in a section-specific configuration shell script after all
# other "config/*.csh" dependencies are sourced as follows
#
#   source config/scenario.csh {{configSection}}

# Multiple functions are created automatically that can be used to parse the particular YAML
# section. Consider the following example:

## forecast.yaml:
#forecast:
#  updateSea: False
#  job:
#    nodes: 2
#    pe: None

# Executing the following command generates the functions described below.
#
#   source confing/scenario.csh forecast
#
# (1) setLocal - uses setenv to create an environment variable with the same name as the lowest
#     hierarchical level of the yaml key.  A missing or "None" value causes an error.
#
# ex:
# $setLocal job.nodes # `setenv nodes 2`
# $setLocal job.pe    # value is None, causes error
# $setLocal nodes     # yaml node does not exist, causes error
# $setLocal updateSea # `setenv updateSea False`
#
#
# (2) getLocalOrNone - returns the value at the applicable YAML key, or None if undefined.  This
#     function is particularly useful for optional entries where the parsing script will define
#     the behavior when the value is undefined.
#
# ex:
# $getLocalOrNone job.nodes # returns "2"
# $getLocalOrNone job.pe    # returns "None"
# $getLocalOrNone nodes     # returns "None"
# $getLocalOrNone updateSea # returns "False"
#
# (3) setNested{{ConfigSection}} - generate "nested" environment variables with a prefix equal to
#     "$configSection__".  The {{ConfigSection}} placeholder is always equal to $configSection,
#     except with the first letter capitalized.  Thus, configSection=forecast becomes
#     ConfigSection=Forecast.  A missing or "None" value causes an error.
#
# ex:
# $setNestedForecast job.nodes # `setenv forecast__nodes 2`
# $setNestedForecast job.pe    # value is None, causes error
# $setNestedForecast nodes     # yaml node does not exist, causes error
# $setNestedForecast updateSea # `setenv forecast__updateSea False`

## configSection (required argument)
# base configuration section defined in scenarios/base/${configSection}.yaml that
# is being parsed by the sourcing script
set configSection = $1

## scenario
# select from pre-defined scenarios (scenarios/*.yaml) or define your own
set scenario = 3dvar_OIE120km_WarmStart

## scenarioDirectory
# The scenario must be described in a yaml file in the scenarioDirectory.  Users can create their
# own unique scenarios by adding options in their scenario YAML that differ from the defaults in
# scenarios/base/*.yaml.  Redundant options with respect to the base YAMLS may also be included
# in the user-defined scenario YAML as desired in order to improve clarity. Note that the default
# values of the base options may change.
set scenarioDirectory = scenarios

## this config
setenv scenarioConfig ${scenarioDirectory}/${scenario}.yaml

source config/config.csh

## define local re-usable configuration parsing functions for this configSection
setenv baseConfig scenarios/base/${configSection}.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig ${configSection}"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig ${configSection}"
set nestedConfigFunctionName = setNested"`echo "${configSection}" | sed 's/.*/\u&/'`"
setenv ${nestedConfigFunctionName} "source $setNestedConfig $baseConfig $scenarioConfig ${configSection}"

#TODO: possibly implement one of below options to reduce config overhead
# (1) create a combined yaml (thisConfig) to avoid double-reading of baseConfig and
#     scenarioConfig [less impactful]
# (2) parse each sub-section of the yaml into environment variables, e.g.,
#     __workflow__VARIABLENAME, to avoid many redundant reads of the entire config
#     [more impactful, added complexity]
# (3) move full config parsing (and task scripts?) into python [most work]
