#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

#from initialize.applications.DA import DA
from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup
from initialize.config.TaskFamily import CylcTaskFamily

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

    groupSettings = ['''
    inherit = '''+parent.tf.group]
    self.tf = CylcTaskFamily(self.base, groupSettings, self['initialize'], self['execute'])

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

    self.active = (relaxationFactor > 0. and members.n > 1 and parent['execute'])

    if self.active:
      self._cshVars += list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    if self.active:
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
  [['''+self.tf.init+'''Job]]
    # note: does not depend on any other tasks
    inherit = '''+self.tf.init+''', SingleBatch
    script = $origin/bin/Init'''+self.base+'''.csh "'''+self.WorkDir+'''"
    execution time limit = PT1M
    execution retry delays = '''+job['retry']+'''
  [['''+self.base+''']]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/'''+self.base+'''.csh "'''+self.WorkDir+'''"
'''+task.job()+task.directives()+'''

  [['''+self.tf.clean+''']]
    script = $origin/bin/Clean'''+self.base+'''.csh "'''+self.WorkDir+'"']

  def export(self, dependency:str, followon:str):
    if self.active:
      # insert between dependency and followon
      self._dependencies += ['''
        '''+dependency+''' => '''+self.tf.pre+'''
        '''+self.tf.finished+''' => '''+followon]

      ###########################
      # update tasks/dependencies
      ###########################
      self._dependencies = self.tf.updateDependencies(self._dependencies)
      self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

      super().export()
