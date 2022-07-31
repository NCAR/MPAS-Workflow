#!/usr/bin/env python3

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

import subprocess
import glob

class Suite():
  ExpConfigType = None
  def drive(self):
    cmd = ['./drive.csh', self.__class__.__name__, self.ExpConfigType]
    print(' '.join(cmd))
    sub = subprocess.run(cmd)

  @staticmethod
  def clean():
    print('cleaning up auto-generated files...')

    cmd = ['rm']
    #cmd += ['-v']

    files = glob.glob("config/auto/*.csh")
    for file in files:
      sub = subprocess.run(cmd+[file])

    files = glob.glob("include/*/auto/*.rc")
    for file in files:
      sub = subprocess.run(cmd+[file])

# Register all suite classes
from initialize.suites.Cycle import Cycle
from initialize.suites.GenerateExternalAnalyses import GenerateExternalAnalyses
from initialize.suites.GenerateObs import GenerateObs
from initialize.suites.ForecastFromExternalAnalyses import ForecastFromExternalAnalyses

suiteDict = {
  'Cycle': Cycle,
  'ForecastFromExternalAnalyses': ForecastFromExternalAnalyses,
  'GenerateExternalAnalyses': GenerateExternalAnalyses,
  'GenerateObs': GenerateObs,
}

def SuiteFactory(suiteName, scenario):
  return suiteDict[suiteName](scenario)
