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
    self._queues = []
    self._dependencies = []
    self._tasks = ["""
## All-task defaults
  [[root]]
    pre-script = "cd  $origin/"
    [[[environment]]]
      origin = {{mainScriptDir}}
    [[[events]]]
      # prevents jobs from sitting in submitted state for longer than 'submission timeout'
      submission timeout = {{submissionTimeout}}
      submission timeout handler = cylc poll %(suite)s '%(id)s:*'; sleep 20; cylc trigger %(suite)s '%(id)s:*' ''']

  [[BATCH]]
    # load conda + activate npl
    init-script = '''
source /etc/profile.d/modules.sh
module load conda/latest
conda activate npl
'''
    # default job
    [[[job]]]
      batch system = pbs
      execution time limit = PT60M

    # default directives, to be overridden by individual tasks
    [[[directives]]]
      -j = oe
      -k = eod
      -S = /bin/tcsh

  [[SingleBatch]]
    # load conda + activate npl
    init-script = '''
source /etc/profile.d/modules.sh
module load conda/latest
conda activate npl
'''
    # default job
    [[[job]]]
      batch system = pbs
      execution time limit = PT60M

    # default directives, to be overridden by individual tasks
    [[[directives]]]
      -j = oe
      -k = eod
      -S = /bin/tcsh
      -q = {{SingleProcQueue}}
      -A = {{SingleProcAccount}}
      -l = select=1:ncpus=1

    # default submission timeout
    [[[events]]]
      submission timeout = PT3M

  [[Clean]]
    [[[job]]]
      execution time limit = PT5M
      execution retry delays = 2*PT15S"""]

  def submit(self):
    self.export()
    cmd = ['./submit.csh', self.__class__.__name__]
    print(' '.join(cmd))
    sub = subprocess.run(cmd)

  def export(self):
    '''
    export for use outside python
    '''
    #self.__exportQueues() # not used yet
    self.__exportTasks()
    self.__exportDependencies()
    return

  ## export methods
  @staticmethod
  def __toTextFile(filename, Str):
    #if len(Str) == 0: return
    #self._msg('Creating '+filename)
    with open(filename, 'w') as f:
      f.writelines(Str)
      f.close()
    return

  # cylc internal scheduling queues
  def __exportQueues(self):
    self.__toTextFile('include/queues/auto/suite.rc', self._queues)
    return

  # cylc dependencies
  def __exportDependencies(self):
    self.__toTextFile('include/dependencies/auto/suite.rc', self._dependencies)
    return

  # cylc tasks
  def __exportTasks(self):
    self.__toTextFile('include/tasks/auto/suite.rc', self._tasks)
    return

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
