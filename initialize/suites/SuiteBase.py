#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

import os
import subprocess

from initialize.config.Config import Config
from initialize.config.TaskFamily import placeholdertask

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

    self.logPrefix = self.__class__.__name__+': '
    host = os.getenv('NCAR_HOST')
    if host == "derecho":
      self.suiteFileName = 'flow.cylc'
    elif host == "cheyenne":
      self.suiteFileName = 'suite.rc'

  def __msg(self, text):
    print(self.logPrefix+text)
    return

  def submit(self):
    scriptDir = self.c['experiment']['mainScriptDir']
    cmd = ['rm', '-rf', scriptDir]
    self.__msg(' '.join(cmd))
    sub = subprocess.run(cmd)

    cmd = ['mkdir', '-p', scriptDir]
    self.__msg(' '.join(cmd))
    sub = subprocess.run(cmd)

    host = os.getenv('NCAR_HOST')
    cylcEnv = os.getenv('CYLC_ENV')
    if host == "derecho":
      modScript = '/etc/profile.d/z00_modules.sh'
      conda = cylcEnv
    elif host == "cheyenne":
      modScript = '/etc/profile.d/modules.sh'
      conda = 'npl'
    else:
      modScript = ''
      conda = ''

    ## task defaults inherited by others
    self._tasks += ["""
  [[root]]
    pre-script = "cd  $origin/"
    [[[environment]]]
      origin = """+scriptDir+"""
    [[[events]]]
      # prevents jobs from sitting in submitted state for longer than 'submission timeout'
      submission timeout = """+self.c['workflow']['submission timeout']+"""
      submission timeout handlers = cylc poll %(workflow)s '%(id)s:*'; sleep 20; cylc trigger %(workflow)s '%(id)s:*' ''']

  [[BATCH]]
    # load conda + activate """ + conda + """
    init-script = '''
source """ + modScript + """
module load conda//latest
conda activate """ + conda + """

'''
    # default job and directives
"""+self.c['hpc'].multitask.job()+self.c['hpc'].multitask.directives()+"""

  [[SingleBatch]]
    # load conda + activate npl
    init-script = '''
source """ + modScript + """
module load conda/latest
conda activate """ + conda + """
'''
    # default job and directives
"""+self.c['hpc'].singletask.job()+self.c['hpc'].singletask.directives()+"""

    # override submission timeout
    [[[events]]]
      submission timeout = PT3M

  [["""+placeholdertask+"""]]"""]

    for k in self.queueComponents:
      self._queues += ['''
    # '''+ k]
      self._queues += self.c[k]._queues
      self._queues += ['''
    [[['''+placeholdertask+''']]]
      members = '''+placeholdertask+'''
      limit = '''+str(self.c['workflow']['max concurrent placeholder tasks'])]

    for k in self.dependencyComponents:
      self._dependencies += ['''
    # '''+ k]
      self._dependencies += self.c[k]._dependencies

    for k in self.taskComponents:
      self._tasks += ['''
  # '''+ k]
      self._tasks += self.c[k]._tasks

    self.__export()

    suiteSpec = [
      'bin',
      'config',
      'scenarios',
      self.suiteFileName,
      'test',
      'tools',
    ]
    for spec in suiteSpec:
      cmd = ['cp', '-rP', spec, scriptDir+'/']
      self.__msg(' '.join(cmd))
      sub = subprocess.run(cmd)

    cmd = ['./submit.csh']
    self.__msg(' '.join(cmd))
    sub = subprocess.run(cmd)

  def __export(self):
    '''
    export suite file that instructs cylc
    '''
    # define suite file
    suiterc = [
'''

# '''+self.suiteFileName+''' is automatically generated.  Modifying it directly will not give the
#  intended result.  See '''+self.__class__.__name__+''' class for implementation information.

[meta]
  title = '''+self.c['experiment']['title']+'''

[scheduler]
  UTC mode = False

[scheduling]
  initial cycle point = '''+self.c['workflow']['restart cycle point']+'''
  final cycle point   = '''+self.c['workflow']['final cycle point']+'''

  # Maximum number of simultaneous active dates;
  # useful for constraining non-blocking flows
  # and to avoid over-utilization of login nodes
  # hint: execute 'ps aux | grep $USER' to check your login node overhead
  # default: 3
  runahead limit = P'''+str(self.c['workflow']['max active cycle points']-1)+'''

  [[queues]]
'''+''.join(self._queues)+'''

  [[graph]]
'''+''.join(self._dependencies)+'''

[runtime]
'''+''.join(self._tasks)]

    # write suite to text file
    with open(self.suiteFileName, 'w') as f:
      f.writelines(suiterc)
      f.close()
    return

# Register all suite classes
from initialize.suites.Cycle import Cycle
from initialize.suites.GenerateExternalAnalyses import GenerateExternalAnalyses
from initialize.suites.GenerateObs import GenerateObs
from initialize.suites.ForecastFromExternalAnalyses import ForecastFromExternalAnalyses
from initialize.suites.CloudDirectInsertion import CloudDirectInsertion

suiteDict = {
  'Cycle': Cycle,
  'ForecastFromExternalAnalyses': ForecastFromExternalAnalyses,
  'GenerateExternalAnalyses': GenerateExternalAnalyses,
  'GenerateObs': GenerateObs,
  'CloudDirectInsertion': CloudDirectInsertion,
}

def SuiteLookup(suiteName:str, conf:Config):
  return suiteDict[suiteName](conf)
