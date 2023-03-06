#!/usr/bin/env python3

from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

from initialize.framework.HPC import HPC

from initialize.data.Model import Mesh
from initialize.data.StateEnsemble import StateEnsemble

class VerifyModel(Component):
  defaults = 'scenarios/defaults/verifymodel.yaml'
  workDir = 'Verification'
  diagnosticsDir = 'diagnostic_stats/model'
  variablesWithDefaults = {
    'script directory': ['/glade/work/guerrett/pandac/fixed_input/graphics_ioda-conventions', str],
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

    self.group += subDirectory.upper()
    parentName = self.group
    self.group += '-'+dtStr+'hr'
    self.finished = self.group+'Finished'
    self.clean = 'Clean'+self.group

    # generic Post tasks and dependencies
    self._tasks += ['''
  [['''+parentName+''']]
  [['''+self.group+''']]
    inherit = '''+parentName+'''
'''+task.job()+task.directives()+'''
  [['''+self.finished+''']]
    inherit = '''+parentName+'''
  [['''+self.clean+''']]
    inherit = Clean''']

    self._dependencies += ['''
        '''+self.group+''':succeed-all => '''+self.finished]

    for d in dependencies:
      self._dependencies += ['''
        '''+d+''' => '''+self.group]

    for f in followon:
      self._dependencies += ['''
        '''+self.finished+''' => '''+f]

    # class-specific tasks
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

      self.execute = self.group
      if NN > 1:
        self.execute += '_'+str(mm+1)
      elif memberMultiplier > 1:
        self.execute += '_MEAN'
      else:
        self.execute += '00'

      self._tasks += ['''
  [['''+self.execute+''']]
    inherit = '''+self.group+''', BATCH
    script = $origin/bin/'''+self.base+'''.csh '''+runArgs]

  def export(self):
    '''
    export for use outside python
    '''
    self._exportVarsToCsh()
    self._exportVarsToCylc()
    return
