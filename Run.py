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
from config.Config import Config
from Drive import Drive
from pathlib import Path

def main():
  '''
  main program
  '''
  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('name', type=str,
                  help='name of run; i.e., {{runConfig}} part of {{runConfig}}.yaml')
  args = ap.parse_args()

  r = Run('runs/base.yaml', 'runs/'+args.name+'.yaml')
  r.execute()


class Run():
  def __init__(self, defaults, run):
    self.logPrefix = self.__class__.__name__+': '

    d = Path(defaults)
    assert d.is_file(), (self.logPrefix+'defaults ('+defaults+') is not a file')
    r = Path(run)
    assert r.is_file(), (self.logPrefix+'run ('+run+') is not a file')

    print('(INFO): Running the set of scenarios described by '+run)

    self.__run = Config(d, r, 'run')
    self.__restore = Config(d, r, 'restore')

  def execute(self):
    '''
    execute the scenarios
    '''
    # scenario settings
    scenarios = self.__run.getOrDie('scenarios')
    directory = self.__run.getOrDie('scenarioDirectory')

    # suite settings
    suite = self.__run.getOrDie('suite')
    appIndependentConfigs = self.__run.getOrDie('appIndependentConfigs')
    appDependentConfigs = self.__run.getOrDie('appDependentConfigs')
    ExpConfigType = self.__run.getOrDie('ExpConfigType')

    for scenario in scenarios:
      print("#########################################################################")
      print("Executing Drive for "+scenario)
      print("#########################################################################")

      d = Drive(
        scenario, directory,
        suite,
        ExpConfigType,
        appIndependentConfigs,
        appDependentConfigs,
      )
      d.execute()

    # restore settings
    restScenario = self.__restore.getOrDie('scenario')
    restDirectory = self.__restore.getOrDie('scenarioDirectory')

    # TODO: remove after config/scenario.csh is python-ified
    d.restore(restScenario, restDirectory)

## execute main program
if __name__ == '__main__': main()
