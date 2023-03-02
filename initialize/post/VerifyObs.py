#!/usr/bin/env python3


from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

from initialize.framework.HPC import HPC

from initialize.data.Model import Model, Mesh
from initialize.data.ObsEnsemble import ObsEnsemble
from initialize.data.StateEnsemble import StateEnsemble

from initialize.post.HofX import HofX

class VerifyObs(Component):
  defaults = 'scenarios/defaults/verifyobs.yaml'
  workDir = 'Verification'
  diagnosticsDir = 'diagnostic_stats/obs'
  variablesWithDefaults = {
    'script directory': ['/glade/work/guerrett/pandac/fixed_input/graphics_ioda-conventions', str],
  }

  def __init__(self,
    config:Config,
    localConf:dict,
    hpc:HPC,
    mesh:Mesh,
    model:Model,
    states:StateEnsemble = None,
    obs:ObsEnsemble = None,
  ):
    super().__init__(config)

    base = self.__class__.__name__

    subDirectory = str(localConf['sub directory'])
    dependencies = list(localConf.get('dependencies', []))
    followon = list(localConf.get('followon', []))
    memberMultiplier = int(localConf.get('member multiplier', 1))

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
    task = TaskLookup[hpc.system](job)

    self.groupName = self.__class__.__name__

    for f in followon:
      self._dependencies += ['''
      '''+self.groupName+''' => '''+f]

    msg = base+': one and only one of states or obs must be defined'
    if obs is None:
      assert states is not None, msg
      self.__hofx = HofX(config, localConf, hpc, mesh, model, states)
      obsLocal = self.__hofx.outputs['obs']['members']

      self._dependencies += ['''
      '''+self.__hofx.groupName+''' => '''+self.groupName]

      appType = 'hofx'

    else:
      assert states is None, msg
      self.__hofx = None
      obsLocal = obs

      for d in dependencies:
        self._dependencies += ['''
      '''+d+''' => '''+self.groupName]

      appType = 'variational'

    if len(obsLocal) > 1:
      memFmt = '/mem{:03d}'
    else:
      memFmt = '/mean'

    # tasks
    self.groupName = base+subDirectory.upper()
    self._tasks += ['''
  [['''+self.groupName+''']]
'''+task.job()+task.directives()]

    dt = obsLocal.duration()
    dtStr = str(dt)

    for mm, o in enumerate(obsLocal):
      workDir = self.workDir+'/'+subDirectory+'/{{thisCycleDate}}'+memFmt.format(mm)
      if dt > 0 or 'fc' in subDirectory:
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

      taskName = self.groupName+str(mm)+'-'+dtStr+'hr'
      self._tasks += ['''
  [['''+taskName+''']]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/bin/'''+base+'''.csh '''+AppArgs]

  def export(components):
    if self.__hofx is not None:
      self._tasks += self.__hofx._tasks
      self._dependencies += self.__hofx._dependencies
      self._dependencies += ['''
       '''+self.groupName+''' => '''+self.__hofx.clean]

    return
