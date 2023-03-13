#!/usr/bin/env python3

import subprocess

from initialize.config.Config import Config

from initialize.framework.HPC import HPC
from initialize.framework.Workflow import Workflow

class SuiteBase():
  def __init__(self, conf:Config):
    self.c = {}
    self.c['hpc'] = HPC(conf)
    self.c['workflow'] = Workflow(conf)
    self.c['experiment'] = None

    self.queueComponents = []
    self.dependencyComponents = []
    self.taskComponents = []

    self._queues = []
    self._dependencies = []
    self._tasks = []

  def submit(self):
    ## task defaults inherited by others
    self._tasks += ["""
  [[root]]
    pre-script = "cd  $origin/"
    [[[environment]]]
      origin = """+self.c['experiment']['mainScriptDir']+"""
    [[[events]]]
      # prevents jobs from sitting in submitted state for longer than 'submission timeout'
      submission timeout = """+self.c['workflow']['submission timeout']+"""
      submission timeout handler = cylc poll %(suite)s '%(id)s:*'; sleep 20; cylc trigger %(suite)s '%(id)s:*' ''']

  [[BATCH]]
    # load conda + activate npl
    init-script = '''
source /etc/profile.d/modules.sh
module load conda/latest
conda activate npl
'''
    # default job and directives
"""+self.c['hpc'].multitask.job()+self.c['hpc'].multitask.directives()+"""

  [[SingleBatch]]
    # load conda + activate npl
    init-script = '''
source /etc/profile.d/modules.sh
module load conda/latest
conda activate npl
'''
    # default job and directives
"""+self.c['hpc'].singletask.job()+self.c['hpc'].singletask.directives()+"""

    # override submission timeout
    [[[events]]]
      submission timeout = PT3M

  [[Clean]]
    [[[job]]]
      execution time limit = PT5M
      execution retry delays = 2*PT15S"""]

    for k in self.queueComponents:
      self._queues += ['''
    # '''+ k]
      self._queues += self.c[k]._queues

    for k in self.dependencyComponents:
      self._dependencies += ['''
    # '''+ k]
      self._dependencies += self.c[k]._dependencies

    for k in self.taskComponents:
      self._tasks += ['''
  # '''+ k]
      self._tasks += self.c[k]._tasks

    self.__export()
    cmd = ['./submit.csh']
    print(' '.join(cmd))
    sub = subprocess.run(cmd)

  def __export(self):
    '''
    export suite.rc that instructs cylc
    '''
    # define suite.rc
    suiterc = [
'''#!Jinja2

# experiment for mainScriptDir (needed by Hofx and Variational)
%include include/variables/auto/experiment.rc

# workflow for "double-date-substitution" variables
%include include/variables/auto/workflow.rc

[meta]
  title = '''+self.c['experiment']['title']+'''

[cylc]
  UTC mode = False

[scheduling]
  initial cycle point = '''+self.c['workflow']['restart cycle point']+'''
  final cycle point   = '''+self.c['workflow']['final cycle point']+'''

  # Maximum number of simultaneous active dates;
  # useful for constraining non-blocking flows
  # and to avoid over-utilization of login nodes
  # hint: execute 'ps aux | grep $USER' to check your login node overhead
  # default: 3
  max active cycle points = '''+str(self.c['workflow']['max active cycle points'])+'''

  [[queues]]
'''+''.join(self._queues)+'''

  [[dependencies]]
'''+''.join(self._dependencies)+'''

[runtime]
'''+''.join(self._tasks)+'''

[visualization]
  initial cycle point = '''+self.c['workflow']['restart cycle point']+'''
  final cycle point   = '''+self.c['workflow']['final cycle point']+'''
  number of cycle points = 200
  default node attributes = "style=filled", "fillcolor=grey"''']

    # write suite.rc to text file
    with open('suites/auto/suite.rc', 'w') as f:
      f.writelines(suiterc)
      f.close()
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
