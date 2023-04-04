#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup
from initialize.config.TaskFamily import CylcTaskFamily

from initialize.framework.HPC import HPC

from initialize.data.Model import Mesh
from initialize.data.StateEnsemble import StateEnsemble

class VerifyModel(Component):
  defaults = 'scenarios/defaults/verifymodel.yaml'
  workDir = 'Verification'
  diagnosticsDir = 'diagnostic_stats/model'
  variablesWithDefaults = {
    'script directory': ['/glade/work/guerrett/pandac/fixed_input/graphics_mpasScoreCard_iodaV3_latest', str],
  }

  def __init__(self,
    config:Config,
    localConf:dict,
  ):
    super().__init__(config)

    hpc = localConf['hpc']; assert isinstance(hpc, HPC), self.base+': incorrect type for hpc'
    mesh = localConf['mesh']; assert isinstance(mesh, Mesh), self.base+': incorrect type for mesh'
    states = localConf['states']; assert isinstance(states, StateEnsemble), self.base+': incorrect type for states'

    subDirectory = str(localConf['sub directory'])
    dependencies = list(localConf.get('dependencies', []))
    followon = list(localConf.get('followon', []))
    memberMultiplier = int(localConf.get('member multiplier', 1))

    dt = states.duration()
    dtStr = str(dt)
    NN = len(states)

    if len(states) > 1:
      memFmt = Members.fmt
    else:
      memFmt = '/mean'

    ###################
    # derived variables
    ###################
    self._set('ModelDiagnosticsDir', self.diagnosticsDir) #used by comparemodel.csh

    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    ## generic tasks and dependencies
    parent = self.base + subDirectory.upper()
    group = parent+'-'+dtStr+'hr'
    groupSettings = ['''
    inherit = '''+parent+'''
  [['''+parent+''']]''']

    self.tf = CylcTaskFamily(group, groupSettings, self['initialize'], self['execute'])
    self.tf.addDependencies(dependencies)
    self.tf.addFollowons(followon)

    ## class-specific tasks
    # job settings
    attr = {
      'retry': {'typ': str},
      'seconds': {'typ': int},
      'secondsPerMember': {'typ': int},
      'nodes': {'def': 1, 'typ': int},
      'PEPerNode': {'def': 36, 'typ': int},
      'memory': {'def': '45GB', 'typ': str},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    job = Resource(self._conf, attr, ('job', mesh.name))
    job['seconds'] += job['secondsPerMember'] * memberMultiplier
    task = TaskLookup[hpc.system](job)

    for mm, state in enumerate(states):
      workDir = self.workDir+'/'+subDirectory+memFmt.format(mm+1)+'/{{thisCycleDate}}'
      if dt > 0 or 'fc' in subDirectory:
        workDir += '/'+dtStr+'hr'
      workDir += '/'+self.diagnosticsDir

      # run
      args = [
        dt,
        workDir,
        state.directory(),
        state.prefix(),
        memberMultiplier,
      ]
      runArgs = ' '.join(['"'+str(a)+'"' for a in args])

      execute = self.tf.execute
      if NN > 1:
        execute += '_'+str(mm+1)
      elif memberMultiplier > 1:
        execute += '_MEAN'
      else:
        execute += '00'

      self._tasks += ['''
  [['''+execute+''']]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/'''+self.base+'''.csh '''+runArgs+'''
'''+task.job()+task.directives()]

  def export(self):
    '''
    export for use outside python
    '''
    ##############
    # update tasks
    ##############
    self._dependencies = self.tf.updateDependencies(self._dependencies)
    self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

    super().export()
    return
