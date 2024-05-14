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
import os
from pathlib import Path
import subprocess

# local modules
from initialize.config.Config import Config
from initialize.config.Logger import Logger
from initialize.config.Scenario import Scenario
from initialize.suites.SuiteBase import SuiteLookup

def main():
  '''
  main program
  '''
  hname = os.getenv('NCAR_HOST')
  cylc = os.getenv('CYLC_ENV')
  if  hname == "derecho" and cylc is None:
    print('CYLC_ENV environment variable is not set, setting it to /glade/work/jwittig/conda-envs/my-cylc8.2')
    os.environ['CYLC_ENV'] = '/glade/work/jwittig/conda-envs/my-cylc8.2'

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

    for scenarioFile in scenarios:
      assert Path(scenarioFile).is_file(), (self.logPrefix+'scenario ('+scenarioFile+') does not exist')

      print("#########################################################################")
      print("Running the scenario: "+scenarioFile)
      print("#########################################################################")

      self.clean()

      scenario = Scenario(scenarioFile)
      scenario.initialize()

      # suite name (defaults to Cycle)
      suiteName = scenario.getConfig().getOrDefault('suite', 'Cycle')

      suite = SuiteLookup(suiteName, scenario.getConfig())
      suite.submit()

    self.clean()

  @staticmethod
  def clean():
    logger = Logger()
    logger.log('cleaning up auto-generated files...', level=logger.MSG_DEBUG)

    for g in [
      "config/auto/*.csh",
      "suite.rc",
    ]:
      files = glob.glob(g)
      for file in files:
        sub = subprocess.run(['rm', file])

## execute main program
if __name__ == '__main__': main()
