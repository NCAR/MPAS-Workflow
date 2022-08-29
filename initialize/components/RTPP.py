#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class RTPP(Component):
  defaults = 'scenarios/defaults/rtpp.yaml'
  workDir = 'CyclingInflation/RTPP'

  variablesWithDefaults = {
    ## relaxationFactor
    # parameter for the relaxation to prior perturbation (RTPP) mechanism
    # only applies to EDA cycling and must be set in order to use RTPP
    # Typical Values: 0. to 0.9
    'relaxationFactor': [0., float],

    ## retainOriginalAnalyses
    # whether to retain the analyses taken as inputs to RTPP
    # OPTIONS: True/False
    'retainOriginalAnalyses': [False, bool],
  }

  def __init__(self, config, hpc, ensMesh, members, da, ensBackgrounds:list, ensAnalyses:list):
    super().__init__(config)

    # WorkDir is where RTPP is executed
    self.WorkDir = self.workDir+'/{{thisCycleDate}}'

    ###################
    # derived variables
    ###################
    self._set('appyaml', 'rtpp.yaml')
    relaxationFactor = self['relaxationFactor']
    assert relaxationFactor >= 0. and relaxationFactor <= 1., (
      self._msg('invalid relaxationFactor: '+str(relaxationFactor)))

    # used by experiment naming convention
    self._set('rtpp__relaxationFactor', relaxationFactor)

    active = (relaxationFactor > 0. and members.n > 1)

    if active:
      self._cshVars += list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    if active:
      attr = {
        'retry': {'t': str},
        'baseSeconds': {'t': int},
        'secondsPerMember': {'t': int},
        'nodes': {'t': int},
        'PEPerNode': {'t': int},
        'memory': {'def': '45GB', 't': str},
        'queue': {'def': hpc['CriticalQueue']},
        'account': {'def': hpc['CriticalAccount']},
        'email': {'def': True, 't': bool},
      }
      job = Resource(self._conf, attr, ('job', ensMesh.name))
      job._set('seconds', job['baseSeconds'] + job['secondsPerMember'] * members.n)
      task = TaskFactory[hpc.system](job)

      da._tasks += ['''
  [[PrepRTPP]]
    # note: does not depend on any other tasks
    inherit = '''+da.groupName+''', SingleBatch
    script = $origin/applications/PrepRTPP.csh "'''+self.WorkDir+'''"
    [[[job]]]
      execution time limit = PT1M
      execution retry delays = '''+job['retry']+'''
  [[RTPP]]
    inherit = '''+da.groupName+''', BATCH
    script = $origin/applications/RTPP.csh "'''+self.WorkDir+'''"
'''+task.job()+task.directives()+'''

  [[CleanRTPP]]
    inherit = Clean, '''+da.clean+'''
    script = $origin/applications/CleanRTPP.csh "'''+self.WorkDir+'"']

      da._dependencies += ['''
        PrepRTPP => RTPP
        '''+da.post+''' => RTPP => '''+da.finished]
