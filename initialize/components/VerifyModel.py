#!/usr/bin/env python3

from initialize.components.HPC import HPC
from initialize.components.Mesh import Mesh

from initialize.Component import Component
from initialize.Config import Config
from initialize.data.StateEnsemble import StateEnsemble
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class VerifyModel(Component):
  defaults = 'scenarios/defaults/verifymodel.yaml'
  workDir = 'Verification'
  diagnosticsDir = 'diagnostic_stats/model'
  variablesWithDefaults = {
    'script directory': ['/glade/work/guerrett/pandac/fixed_input/graphics_ioda-conventions', str],
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
    mesh:Mesh,
    label:str,
    dependencies:list,
    followon:list,
    memberMultiplier:int,
    states:StateEnsemble = None,
  ):

    super().__init__(config)

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
    task = TaskFactory[hpc.system](job)

    self.groupName = self.__class__.__name__

    for f in followon:
      self._dependencies += ['''
      '''+self.groupName+''' => '''+f]

    # tasks
    base = self.__class__.__name__
    self.groupName = base+label.upper()
    self._tasks += ['''
  [['''+self.groupName+''']]
'''+task.job()+task.directives()]

    dt = states.duration()
    dtStr = str(dt)

    for mm, state in enumerate(states):
      workDir = self.WorkDir+'/'+label+'/{{thisCycleDate}}'+memFmt.format(mm)
      if dt > 0 or label == 'fc':
        workDir += '/'+dtStr+'hr'
      workDir += '/'+diagnosticsDir

      args = [
        dt,
        workDir,
        state.directory(),
        state.prefix(),
        memberMultiplier,
      ]
      AppArgs = ' '.join(['"'+str(a)+'"' for a in args])

      self._tasks += ['''
  [['''+self.groupName+str(mm)+'-'+dtStr+'hr]]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/'''+base+'''.csh '''+AppArgs]

    # dependencies
    for d in dependencies:
      self._dependencies += ['''
        '''+d+''' => '''+self.groupName]

  def export(components):
    return
