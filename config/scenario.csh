#!/bin/csh -f

#if ( $?config_scenario ) exit 0
#set config_scenario = 1

# This script sets up the environment needed to parse particular sections of the
# scenario configuration YAML.

# It should be sourced after all other "config/*.csh" scripts are sourced as follows
#
#   source config/scenario.csh {{configSection}} {{nestedConfigFunctionName}}

# Process arguments
# =================
## configSection (required 1st argument)
# base configuration section defined in scenarios/base/ that is being referenced
# by the sourcing script
set configSection = $1

## nestedConfigFunctionName (required 2nd argument)
# function name for extracting configSection-specific nested components of the configuration for
# global use by external scripts.  This is usseful when multiple applications re-use similar configuration
# elements.  E.g., variational__nodes must not conflict with hofx__nodes.
set nestedConfigFunctionName = $2

# E.g., for config/model.csh, the appropriate usage is
#
#   source config/scenario.csh model setNestedModel
#
# In this case, the $setNestedModel function will generate "nested" environment variables with the
# "model__" prefix.  The following line would result in a new global environment variable named
# "model__precision".
# $setNestedModel precision
#
# This is akin to a public object member variable in OO programming.

# Dependencies
# ============
source config/config.csh

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
# + RealTime
# + IASI_3denvar_OIE120km_WarmStart
set scenario = 3dvar_OIE120km_WarmStart

## scenarioDirectory
# The scenario must be described in a yaml file in the scenarioDirectory.  Users can create their
# own unique scenarios be adding options in their scenario YAML that differ from the defaults in
# scenarios/base/*.yaml.  Redundant options with respect to the base YAMLS may also be included
# in the user-defined scenario YAML as desired to improve clarity.
set scenarioDirectory = scenarios

## this config
setenv scenarioConfig ${scenarioDirectory}/${scenario}.yaml

## define local re-usable configuration parsing functions for this configSection
setenv baseConfig scenarios/base/${configSection}.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig ${configSection}"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig ${configSection}"
setenv ${nestedConfigFunctionName} "source $setNestedConfig $baseConfig $scenarioConfig ${configSection}"

#TODO: possibly implement one of below options to reduce config overhead
# (1) create a combined yaml (thisConfig) to avoid double-reading of baseConfig and
#     scenarioConfig [less impactful]
# (2) parse each sub-section of the yaml into environment variables, e.g.,
#     __workflow__VARIABLENAME, to avoid many redundant reads of the entire config
#     [more impactful, added complexity]
# (3) move full config parsing (and task scripts?) into python [most work]
