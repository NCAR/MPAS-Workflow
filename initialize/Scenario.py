#!/usr/bin/env python3

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

class Scenario():
  def __init__(self, directory, name):
    self.__conf = directory+'/'+name+'.yaml'
    self.__script = [
'''#!/bin/csh -f

## configSection (required argument)
# base configuration section defined in scenarios/base/${configSection}.yaml that
# is being parsed by the sourcing script
set configSection = $1

## this config
setenv scenarioConfig '''+self.__conf+'''

source config/config.csh

## define local re-usable configuration parsing functions for this configSection
setenv baseConfig scenarios/base/${configSection}.yaml
setenv setLocal "source $setConfig $baseConfig $scenarioConfig ${configSection}"
setenv getLocalOrNone "source $getConfigOrNone $baseConfig $scenarioConfig ${configSection}"
set nestedConfigFunctionName = setNested"`echo "${configSection}" | sed 's/.*/\\u&/'`"
setenv ${nestedConfigFunctionName} "source $setNestedConfig $baseConfig $scenarioConfig ${configSection}"
''']
  def get(self):
    return self.__conf

  #TODO: python-ify all config shell scripts such that config/scenario.csh is no longer needed
  def initialize(self):
    with open('config/scenario.csh', 'w') as file:
      file.writelines(self.__script)
      file.close()
