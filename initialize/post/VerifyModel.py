#!/usr/bin/env python3

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
    hpc:HPC,
    mesh:Mesh,
    states:StateEnsemble,
  ):
    super().__init__(config)

    base = self.__class__.__name__

    subDirectory = str(localConf['sub directory'])
    dependencies = list(localConf.get('dependencies', []))
    followon = list(localConf.get('followon', []))
    memberMultiplier = int(localConf.get('member multiplier', 1))

    dt = states.duration()
    dtStr = str(dt)
    NN = len(states)

    if len(states) > 1:
      memFmt = '/mem{:03d}'
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
      'retry': {'t': str},
      'seconds': {'t': int},
      'secondsPerMember': {'t': int},
      'nodes': {'def': 1, 't': int},
      'PEPerNode': {'def': 36, 't': int},
      'memory': {'def': '45GB', 't': str},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    job = Resource(self._conf, attr, ('job', mesh.name))
    job['seconds'] += job['secondsPerMember'] * memberMultiplier
    task = TaskLookup[hpc.system](job)

    self.groupName = base+subDirectory.upper()
    parentName = self.groupName
    self.groupName += '-'+dtStr+'hr'
    self.finished = self.groupName+'Finished'
    self.clean = 'Clean'+self.groupName

    # generic Post tasks and dependencies
    self._tasks += ['''
  [['''+parentName+''']]
  [['''+self.groupName+''']]
    inherit = '''+parentName+'''
'''+task.job()+task.directives()+'''
  [['''+self.finished+''']]
    inherit = '''+parentName+'''
  [['''+self.clean+''']]
    inherit = Clean''']

    self._dependencies += ['''
        '''+self.groupName+''':succeed-all => '''+self.finished]

    for d in dependencies:
      self._dependencies += ['''
        '''+d+''' => '''+self.groupName]

    for f in followon:
      self._dependencies += ['''
        '''+self.finished+''' => '''+f]

    # class-specific tasks
    for mm, state in enumerate(states):
      workDir = self.workDir+'/'+subDirectory+'/{{thisCycleDate}}'+memFmt.format(mm+1)
      if dt > 0 or 'fc' in subDirectory:
        workDir += '/'+dtStr+'hr'
      workDir += '/'+self.diagnosticsDir

      args = [
        dt,
        workDir,
        state.directory(),
        state.prefix(),
        memberMultiplier,
      ]
      AppArgs = ' '.join(['"'+str(a)+'"' for a in args])

      if NN > 1:
        taskName = self.groupName+'_'+str(mm+1)
      else:
        taskName = self.groupName+'_MEAN'

      self._tasks += ['''
  [['''+taskName+''']]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/bin/'''+base+'''.csh '''+AppArgs]

  def export(self, components):
    '''
    export for use outside python
    '''
    self._exportVarsToCsh()
    self._exportVarsToCylc()
    return
