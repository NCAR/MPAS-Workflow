#!/usr/bin/env python3

#from initialize.applications.DA import DA
from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

from initialize.data.Model import Mesh
from initialize.data.Observations import Observations
from initialize.data.StateEnsemble import StateEnsemble

from initialize.framework.HPC import HPC

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

  def __init__(self,
    config:Config,
    hpc:HPC,
    mesh:Mesh,
    members:Members,
    parent:Component,
    ensBackgrounds:StateEnsemble,
    ensAnalyses:StateEnsemble,
  ):
    self.NN = members.n
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
        'retry': {'typ': str},
        'baseSeconds': {'typ': int},
        'secondsPerMember': {'typ': int},
        'nodes': {'typ': int},
        'PEPerNode': {'typ': int},
        'memory': {'def': '45GB', 'typ': str},
        'queue': {'def': hpc['CriticalQueue']},
        'account': {'def': hpc['CriticalAccount']},
        'email': {'def': True, 'typ': bool},
      }
      job = Resource(self._conf, attr, ('job', mesh.name))
      job._set('seconds', job['baseSeconds'] + job['secondsPerMember'] * members.n)
      task = TaskLookup[hpc.system](job)

      self._tasks += ['''
  [[Prep'''+self.base+''']]
    # note: does not depend on any other tasks
    inherit = '''+parent.group+''', SingleBatch
    script = $origin/bin/Prep'''+self.base+'''.csh "'''+self.WorkDir+'''"
    [[[job]]]
      execution time limit = PT1M
      execution retry delays = '''+job['retry']+'''
  [['''+self.base+''']]
    inherit = '''+parent.group+''', BATCH
    script = $origin/bin/'''+self.base+'''.csh "'''+self.WorkDir+'''"
'''+task.job()+task.directives()+'''

  [['''+self.clean+''']]
    inherit = Clean, '''+parent.clean+'''
    script = $origin/bin/'''+self.clean+'''.csh "'''+self.WorkDir+'"']

      self._dependencies += ['''
        Prep'''+self.base+''' => '''+self.base+'''
        '''+parent.post+''' => '''+self.base+''' => '''+parent.finished]
