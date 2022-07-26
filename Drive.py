#!/usr/bin/env python3

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

import subprocess

class Drive():
  def __init__(self, scenario, directory, suite, ExpConfigType, appIndependentConfigs, appDependentConfigs):

    cmd = [
      'sed', '-i',
      's@^set\ scenario\ =\ .*@set\ scenario\ =\ '+scenario+'@',
      'config/scenario.csh',
    ]
    #print(' '.join(cmd))
    sub = subprocess.run(cmd)

    cmd = [
      'sed', '-i',
      's@^set\ scenarioDirectory\ =\ .*@set\ scenarioDirectory\ =\ '+directory+'@',
      'config/scenario.csh',
    ]
    #print(' '.join(cmd))
    sub = subprocess.run(cmd)

    self.__suite = suite
    self.__ExpConfigType = ExpConfigType

    # application-independent configurations
    for c in appIndependentConfigs:
      cmd = ['./config/'+c+'.csh']
      print(' '.join(cmd))
      sub = subprocess.run(cmd)

    # application-specific configurations
    for app in appDependentConfigs:
      cmd = ['./config/applications/'+app+'.csh']
      print(' '.join(cmd))
      sub = subprocess.run(cmd)

  def execute(self):
    cmd = ['./drive.csh', self.__suite, self.__ExpConfigType]
    print(' '.join(cmd))
    sub = subprocess.run(cmd)

  # TODO: remove after config/scenario.csh is python-ified
  def restore(self, scenario, directory):
    '''
    restore original scenario settings
    '''
    cmd = [
      'sed', '-i',
      's@^set\ scenario\ =\ .*@set\ scenario\ =\ '+scenario+'@',
      'config/scenario.csh',
    ]
    #print(' '.join(cmd))
    sub = subprocess.run(cmd)

    cmd = [
      'sed', '-i',
      's@^set\ scenarioDirectory\ =\ .*@set\ scenarioDirectory\ =\ '+directory+'@',
      'config/scenario.csh',
    ]
    #print(' '.join(cmd))
    sub = subprocess.run(cmd)
