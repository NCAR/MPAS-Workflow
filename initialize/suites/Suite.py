#!/usr/bin/env python3

####################################################################################################
# This script runs a pre-configure cylc suite scenario described in config/scenario.csh. If the user
# has previously executed this script with the same effecitve "SuiteName" the scenario is
# already running, then executing this script will automatically kill those running suites.
####################################################################################################

import subprocess

from initialize.config.Config import Config

class Suite():
  def __init__(self):
    '''
    virtual method
    '''
    raise NotImplementedError()

  def submit(self):
    cmd = ['./submit.csh', self.__class__.__name__]
    print(' '.join(cmd))
    sub = subprocess.run(cmd)

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

def SuiteLookup(suiteName:str, conf:Config):
  return suiteDict[suiteName](conf)
