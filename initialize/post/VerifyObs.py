#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.applications.HofX import HofX
from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup
from initialize.config.TaskFamily import CylcTaskFamily

from initialize.framework.HPC import HPC

from initialize.data.ObsEnsemble import ObsEnsemble
from initialize.data.StateEnsemble import StateEnsemble

class VerifyObs(Component):
  defaults = 'scenarios/defaults/verifyobs.yaml'
  workDir = 'Verification'
  diagnosticsDir = 'diagnostic_stats/obs'
  variablesWithDefaults = {
    'script directory': ['/glade/work/guerrett/pandac/fixed_input/graphics_mpasScoreCard_iodaV3_latest', str],
  }

  def __init__(self,
    config:Config,
    localConf:dict,
  ):
    super().__init__(config)

    hpc = localConf['hpc']; assert isinstance(hpc, HPC), self.base+': incorrect type for hpc'
    obs = localConf.get('obs', None)

    subDirectory = str(localConf['sub directory'])
    dependencies = list(localConf.get('dependencies', []))
    followon = list(localConf.get('followon', []))
    memberMultiplier = int(localConf.get('member multiplier', 1))

    ###################
    # derived variables
    ###################
    self._set('ObsDiagnosticsDir', self.diagnosticsDir) # used by compareobs.csh
    self._cshVars = list(self._vtable.keys())

    # if obs are passed, defer to them, otherwise generate new obs with HofX
    if obs is None:
      self.__hofx = HofX(config, localConf)
      obsLocal = self.__hofx.outputs['obs']['members']
      appType = 'hofx'

    else:
      assert isinstance (obs, ObsEnsemble), self.base+': incorrect obs instance type'
      self.__hofx = None
      obsLocal = obs
      appType = 'variational'

    dt = obsLocal.duration()
    dtStr = str(dt)
    NN = len(obsLocal)

    if NN > 1:
      memFmt = Members.fmt
    else:
      memFmt = '/mean'

    ########################
    # tasks and dependencies
    ########################
    ## generic tasks and dependencies
    parent = self.base + subDirectory.upper()
    group = parent+'-'+dtStr+'hr'
    groupSettings = ['''
    inherit = '''+parent+'''
  [['''+parent+''']]''']

    self.tf = CylcTaskFamily(group, groupSettings)
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
    job = Resource(self._conf, attr, ('job',))
    job['seconds'] += job['secondsPerMember'] * memberMultiplier
    task = TaskLookup[hpc.system](job)

    for mm, o in enumerate(obsLocal):
      workDir = self.workDir+'/'+subDirectory+memFmt.format(mm+1)+'/{{thisCycleDate}}'
      if dt > 0 or 'fc' in subDirectory:
        workDir += '/'+dtStr+'hr'
      workDir += '/'+self.diagnosticsDir

      # run
      args = [
        dt,
        workDir,
        o.directory(),
        memberMultiplier,
        appType,
        #o.observers(), # incorporate obs selection into DiagnoseObsStats.py yaml/dict
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
    # add hofx tasks and dependencies when applicable
    if self.__hofx is not None:
      self.__hofx.export()
      self._tasks += self.__hofx._tasks
      self._dependencies += self.__hofx._dependencies
      self._dependencies += ['''
        '''+self.__hofx.tf.group+''':succeed-all => '''+self.tf.pre]
      self._dependencies += ['''
        '''+self.tf.group+''':succeed-all => '''+self.__hofx.tf.clean]

    ##############
    # update tasks
    ##############
    self._dependencies = self.tf.updateDependencies(self._dependencies)
    self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

    super().export()
    return
