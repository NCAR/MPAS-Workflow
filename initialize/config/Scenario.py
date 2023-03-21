#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.config.Config import Config

class Scenario():
  def __init__(self, file):
    self.__conf = Config(file)
    self.__script = [
'''#!/bin/csh -f

## configSection (required argument)
# defaults configuration section defined in scenarios/defaults/${configSection}.yaml that
# is being parsed by the sourcing script
set configSection = $1

## this config
setenv scenarioConfig '''+file+'''

source config/config.csh

## define local re-usable configuration parsing functions for this configSection
setenv defaultsConfig scenarios/defaults/${configSection}.yaml
setenv setLocal "source $setConfig $defaultsConfig $scenarioConfig ${configSection}"
setenv getLocalOrNone "source $getConfigOrNone $defaultsConfig $scenarioConfig ${configSection}"
set nestedConfigFunctionName = setNested"`echo "${configSection}" | sed 's/.*/\\u&/'`"
setenv ${nestedConfigFunctionName} "source $setNestedConfig $defaultsConfig $scenarioConfig ${configSection}"
''']

  def getConfig(self):
    return self.__conf

  #TODO: python-ify all config shell scripts such that config/scenario.csh is no longer needed
  def initialize(self):
    '''
    Creates a script used to parse a particular section of the complete scenario configuration
    YAML in any c-shell script.  The primary remaining usage is in applications/PrepJEDI.csh

    It should be sourced in a section-specific configuration shell script after all
    other "config/*.csh" dependencies are sourced as follows

      source config/auto/scenario.csh {{configSection}}

    Multiple functions are created automatically that can be used to parse the particular YAML
    section. Consider the following example:

    # forecast.yaml:
    forecast:
      updateSea: False
      job:
        nodes: 2
        pe: None

    Executing the following command generates the functions described below.

      source confing/scenario.csh forecast

    (1) setLocal - uses setenv to create an environment variable with the same name as the lowest
        hierarchical level of the yaml key.  A missing or "None" value causes an error.

    ex:
    $setLocal job.nodes # `setenv nodes 2`
    $setLocal job.pe    # value is None, causes error
    $setLocal nodes     # yaml node does not exist, causes error
    $setLocal updateSea # `setenv updateSea False`


    (2) getLocalOrNone - returns the value at the applicable YAML key, or None if undefined.  This
        function is particularly useful for optional entries where the parsing script will define
        the behavior when the value is undefined.

    ex:
    $getLocalOrNone job.nodes # returns "2"
    $getLocalOrNone job.pe    # returns "None"
    $getLocalOrNone nodes     # returns "None"
    $getLocalOrNone updateSea # returns "False"

    (3) setNested{{ConfigSection}} - generate "nested" environment variables with a prefix equal to
        "$configSection__".  The {{ConfigSection}} placeholder is always equal to $configSection,
        except with the first letter capitalized.  Thus, configSection=forecast becomes
        ConfigSection=Forecast.  A missing or "None" value causes an error.

    ex:
    $setNestedForecast job.nodes # `setenv forecast__nodes 2`
    $setNestedForecast job.pe    # value is None, causes error
    $setNestedForecast nodes     # yaml node does not exist, causes error
    $setNestedForecast updateSea # `setenv forecast__updateSea False`
    '''

    with open('config/auto/scenario.csh', 'w') as file:
      file.writelines(self.__script)
      file.close()
