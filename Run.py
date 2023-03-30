#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

####################################################################################################
# This script generates a suite.rc file from a pre-configured set MPAS-Workflow scenarios, and then
# submits those suites via Cylc
####################################################################################################

## Usage:
#   source env/cheyenne.${YourShell}
#   ./Run.py {{runConfig}}

# external modules
import argparse
from collections.abc import Iterable
import glob
from pathlib import Path
import subprocess

# local modules
from initialize.config.Config import Config
from initialize.config.Scenario import Scenario
from initialize.suites.SuiteBase import SuiteLookup

def main():
  '''
  main program
  '''
  run = Run()
  run.execute()


class Run():
  def __init__(self):
    self.logPrefix = self.__class__.__name__+': '

    # Parse command line
    ap = argparse.ArgumentParser()
    ap.add_argument('config', type=str,
                    help='configuration file; e.g., runs/test.yaml, scenarios/{{scenarioName}}.yaml')
    args = ap.parse_args()
    assert Path(args.config).is_file(), (self.logPrefix+'config ('+args.config+') does not exist')

    self.__configFile = args.config
    self.__config = Config(args.config)

  def execute(self):
    '''
    execute the scenarios
    '''

    if self.__config.has('scenarios'):
      # scenario location(s)
      scenarios = self.__config.getOrDie('scenarios')
      assert isinstance(scenarios, Iterable), 'scenarios must be a list of scenario files'
    else:
      scenarios = [self.__configFile]

    # suite name (defaults to Cycle)
    suiteName = self.__config.getOrDefault('suite', 'Cycle')

    for scenarioFile in scenarios:
      assert Path(scenarioFile).is_file(), (self.logPrefix+'scenario ('+scenarioFile+') does not exist')

      print("#########################################################################")
      print("Running the scenario: "+scenarioFile)
      print("#########################################################################")

      self.clean()

      scenario = Scenario(scenarioFile)
      scenario.initialize()

      suite = SuiteLookup(suiteName, scenario.getConfig())
      suite.submit()

    self.clean()

  @staticmethod
  def clean():
    print('cleaning up auto-generated files...')

    for g in [
      "config/auto/*.csh",
      "suite.rc",
    ]:
      files = glob.glob(g)
      for file in files:
        sub = subprocess.run(['rm', file])

## execute main program
if __name__ == '__main__': main()
