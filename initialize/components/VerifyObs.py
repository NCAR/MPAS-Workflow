#!/usr/bin/env python3

from initialize.components.HPC import HPC
from initialize.components.Mesh import Mesh
from initialize.components.Model import Model

from initialize.Component import Component
from initialize.Config import Config
from initialize.data.ObsEnsemble import ObsEnsemble
from initialize.data.StateEnsemble import StateEnsemble
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class VerifyObs(Component):
  defaults = 'scenarios/defaults/verifyobs.yaml'
  workDir = 'Verification'
  diagnosticsDir = 'diagnostic_stats/obs'
  variablesWithDefaults = {
    'script directory': ['/glade/work/guerrett/pandac/fixed_input/graphics_ioda-conventions', str],
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
    mesh:Mesh,
    model:Model,
    label:str,
    dependencies:list,
    followon:list,
    memberMultiplier:int,
    states:StateEnsemble = None,
    obs:ObsEnsemble = None,
  ):
    super().__init__(config)

    base = self.__class__.__name__

    ###################
    # derived variables
    ###################
    self._set('ObsDiagnosticsDir', self.diagnosticsDir) # used by compareobs.csh

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
    job = Resource(self._conf, attr, ('job',))
    job['seconds'] += job['secondsPerMember'] * memberMultiplier
    task = TaskFactory[hpc.system](job)

    self.groupName = self.__class__.__name__

    for f in followon:
      self._dependencies += ['''
      '''+self.groupName+''' => '''+f]

    if obs is None:
      assert states is not None, base+': one and only one of states or obs must be defined'
      self.__hofx = HofX(config, hpc, mesh, model, states, label, dependencies)
      obsLocal = self.__hofx.outputs['obs']

      self._dependencies += ['''
      '''+self.__hofx.groupName+''' => '''+self.groupName]

      appType = 'hofx'

    else:
      assert states is None, base+': one and only one of states or obs must be defined'
      self.__hofx = None
      obsLocal = obs
      appType = 'variational'

    # tasks
    self.groupName = base+label.upper()
    self._tasks += ['''
  [['''+self.groupName+''']]
'''+task.job()+task.directives()]

    dt = obs.duration()
    dtStr = str(dt)

    for mm, o in enumerate(obs):
      workDir = self.WorkDir+'/'+label+'/{{thisCycleDate}}'+memFmt.format(mm)
      if dt > 0 or label == 'fc':
        workDir += '/'+dtStr+'hr'
      workDir += '/'+self.diagnosticsDir

      args = [
        dt,
        workDir,
        o.directory(),
        memberMultiplier,
        appType,
        #o.observers(), # incorporate obs selection into DiagnoseObsStats.py yaml/dict
      ]
      AppArgs = ' '.join(['"'+str(a)+'"' for a in args])

      self._tasks += ['''
  [['''+self.groupName+str(mm)+'-'+dtStr+'hr]]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/'''+base+'''.csh '''+AppArgs]

  def export(components):
    if self.__hofx is not None:
      self._tasks += self.__hofx._tasks
      self._dependencies += self.__hofx._dependencies
      self._dependencies += ['''
       '''+self.groupName+''' => '''+self.__hofx.clean]

    return
