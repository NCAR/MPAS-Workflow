#!/usr/bin/env python3

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

import subprocess

class Suite():
  ExpConfigType = None
  appIndependentConfigs = []
  appDependentConfigs = []
  def __init__(self, scenario):
    self.__scenario = scenario.get()

    # application-independent configurations
    for c in self.appIndependentConfigs:
      cmd = ['./config/'+c+'.csh']
      print(' '.join(cmd))
      sub = subprocess.run(cmd)

    # application-specific configurations
    for app in self.appDependentConfigs:
      cmd = ['./config/applications/'+app+'.csh']
      print(' '.join(cmd))
      sub = subprocess.run(cmd)

  def drive(self):
    cmd = ['./drive.csh', self.__class__.__name__, self.ExpConfigType]
    print(' '.join(cmd))
    sub = subprocess.run(cmd)
