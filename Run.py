#!/usr/bin/env python3

####################################################################################################
# This script runs a pre-configured set of cylc suites via MPAS-Workflow. If the user has
# previously executed this script with the same "ArgRunConfig", and one or more of the scenarios is
# already running, then executing this script again will cause drive.csh to kill those running
# suites.
####################################################################################################

## Usage:
#   source env/cheyenne.${YourShell}
#   ./Run.py {{runConfig}}

import argparse
from pathlib import Path

# basic classes
from initialize.Config import Config
from initialize.Scenario import Scenario

# suite classes
from initialize.Cycle import Cycle
from initialize.GenerateExternalAnalyses import GenerateExternalAnalyses
from initialize.GenerateObs import GenerateObs
from initialize.ForecastFromExternalAnalyses import ForecastFromExternalAnalyses

suiteDict = {
  'Cycle': Cycle,
  'ForecastFromExternalAnalyses': ForecastFromExternalAnalyses,
  'GenerateExternalAnalyses': GenerateExternalAnalyses,
  'GenerateObs': GenerateObs,
}

def main():
  '''
  main program
  '''
  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('name', type=str,
                  help='name of run; i.e., {{runConfig}} part of {{runConfig}}.yaml')
  args = ap.parse_args()

  run = Run('runs/base.yaml', 'runs/'+args.name+'.yaml')
  run.execute()


class Run():
  def __init__(self, dconf, rconf):
    self.logPrefix = self.__class__.__name__+': '

    defaults = Path(dconf)
    assert defaults.is_file(), (self.logPrefix+'dconf ('+dconf+') is not a file')

    run = Path(rconf)
    assert run.is_file(), (self.logPrefix+'rconf ('+rconf+') is not a file')

    print('(INFO): Running the set of scenarios described by '+rconf)

    self.__run = Config(defaults, run, 'run')

  def execute(self):
    '''
    execute the scenarios
    '''
    # scenario location(s)
    directory = self.__run.getOrDie('directory')
    scenarios = self.__run.getOrDie('scenarios')

    # suite name
    suiteName = self.__run.getOrDie('suite')

    for scenarioName in scenarios:
      print("#########################################################################")
      print("Running the scenario: "+scenarioName)
      print("#########################################################################")

      scenario = Scenario(directory, scenarioName)
      scenario.initialize()

      suite = suiteDict[suiteName](scenario)
      suite.drive()

## execute main program
if __name__ == '__main__': main()
