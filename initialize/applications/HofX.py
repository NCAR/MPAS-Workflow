#!/usr/bin/env python3

from initialize.framework.HPC import HPC
from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup
from initialize.config.TaskFamily import CylcTaskFamily

from initialize.data.Model import Model, Mesh
from initialize.data.Observations import Observations
from initialize.data.ObsEnsemble import ObsEnsemble
from initialize.data.StateEnsemble import StateEnsemble

class HofX(Component):
  defaults = 'scenarios/defaults/hofx.yaml'
  workDir = 'Verification'

  variablesWithDefaults = {
  ## observers
  # observation types simulated in hofx application instances for verification
  # OPTIONS: see list below
  # Abbreviations:
  #   clr == clear-sky
  #   cld == cloudy-sky
    'observers': [[
      # anchor
      'aircraft',
      'gnssrobndropp1d',
      #'gnssrobndnbam',
      #'gnssrobndmo',
      #'gnssrobndmo-nopseudo',
      #'gnssroref', # UFO obs errors
      'gnssrorefncep', # obs errors derived from cycling exp.
      'satwind',
      'satwnd',
      'sfc',
      'sondes',
      # MW satellite-based
      'amsua_aqua',
      'amsua_metop-a',
      'amsua_metop-b',
      'amsua_n15',
      'amsua_n18',
      'amsua_n19',
      'amsua-cld_aqua',
      'amsua-cld_metop-a',
      'amsua-cld_metop-b',
      'amsua-cld_n15',
      'amsua-cld_n18',
      'amsua-cld_n19',
      'mhs_n19',
      'mhs_n18',
      'mhs_metop-a',
      'mhs_metop-b',
      # IR satellite-based
      'abi_g16',
      'ahi_himawari8',
      #'abi-clr_g16',
      #'ahi-clr_himawari8',
      #'iasi_metop-a',
      #'iasi_metop-b',
      #'iasi_metop-c',
    ], list],

    ## nObsIndent
    # number of spaces to precede members of the 'observers' list in the JEDI YAML
    'nObsIndent': [2, int],

    ## biasCorrection
    # whether to use bias correction coefficients from VarBC
    # OPTIONS: False (not enabled yet)
    'biasCorrection': [False, bool],

    ## tropprsMethod
    # method for the tropopause pressure determination used in the
    # cloud detection filter for infrared observations
    # OPTIONS: thompson, wmo (currently the build code only works for thompson)
    'tropprsMethod': ['thompson', str, ['thompson', 'wmo']],

    ## maxIODAPoolSize
    # maximum number of IO pool members in IODA writer class
    # OPTIONS: 1 to NPE, default: 10
    'maxIODAPoolSize': [10, int],

    ## radianceThinningDistance
    # distance (km) used for the Gaussian Thinning filter for all radiance-based observations
    'radianceThinningDistance': [145.0, float],

    ## retainObsFeedback
    # whether to retain the observation feedback files (obs, geovals, ydiag)
    'retainObsFeedback': [True, bool],
  }

  def __init__(self,
    config:Config,
    localConf:dict,
  ):
    super().__init__(config)

    hpc = localConf['hpc']; assert isinstance(hpc, HPC), self.base+': incorrect type for hpc'
    model = localConf['model']; assert isinstance(model, Model), self.base+': incorrect type for model'
    mesh = localConf['mesh']; assert isinstance(mesh, Mesh), self.base+': incorrect type for mesh'
    states = localConf['states']; assert isinstance(states, StateEnsemble), self.base+': incorrect type for states'

    subDirectory = str(localConf['sub directory'])
    dependencies = list(localConf.get('dependencies', []))
    followon = list(localConf.get('followon', []))
    memberMultiplier = int(localConf.get('member multiplier', 1))

    dt = states.duration()
    dtStr = str(dt)
    NN = len(states)

    if NN > 1:
      memFmt = Members.fmt
    else:
      memFmt = '/mean'

    ###################
    # derived variables
    ###################
    self._set('AppName', 'hofx')
    self._set('appyaml', 'hofx.yaml')

    self._set('MeshList', ['HofX'])
    self._set('nCellsList', [mesh.nCells])
    self._set('StreamsFileList', [model['outerStreamsFile']])
    self._set('NamelistFileList', [model['outerNamelistFile']])

    # all csh variables above
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

    self.TM = CylcTaskFamily(group, groupSettings)
    self.TM.addDependencies(dependencies)
    self.TM.addFollowons(followon)

    ## class-specific tasks

    # job settings
    attr = {
      'retry': {'typ': str},
      'seconds': {'typ': int},
      'nodes': {'typ': int},
      'PEPerNode': {'typ': int},
      'memory': {'def': '45GB', 'typ': str},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    job = Resource(self._conf, attr, ('job', mesh.name))
    task = TaskLookup[hpc.system](job)
    for mm, state in enumerate(states):
      workDir = self.workDir+'/'+subDirectory+memFmt.format(mm+1)+'/{{thisCycleDate}}'
      if dt > 0 or 'fc' in subDirectory:
        workDir += '/'+dtStr+'hr'

      # prep/run
      args = [
        dt,
        self.lower,
        workDir,
        6, # window (hr); TODO: to be provided by parent
      ]
      prepArgs = ' '.join(['"'+str(a)+'"' for a in args])
      prepScript = 'PrepJEDI'

      args = [
        mm+1,
        dt,
        workDir,
        state.directory(),
        state.prefix(),
      ]
      runArgs = ' '.join(['"'+str(a)+'"' for a in args])

      execute = self.TM.execute 
      if NN > 1:
        execute += '_'+str(mm+1)
      elif memberMultiplier > 1:
        execute += '_MEAN'
      else:
        execute += '00'

      self._tasks += ['''
  [['''+execute+''']]
    inherit = '''+self.TM.execute+''', BATCH
    env-script = cd {{mainScriptDir}}; ./bin/'''+prepScript+'''.csh '''+prepArgs+'''
    script = $origin/bin/'''+self.base+'''.csh '''+runArgs+'''
'''+task.job()+task.directives()]

      # clean
      args = [
        dt,
        workDir,
      ]
      CleanArgs = ' '.join(['"'+str(a)+'"' for a in args])

      clean = self.TM.clean 
      if NN > 1:
        clean += '_'+str(mm+1)
      elif memberMultiplier > 1:
        clean += '_MEAN'
      else:
        clean += '00'

      self._tasks += ['''
  [['''+clean+''']]
    inherit = '''+self.TM.clean+'''
    script = $origin/bin/Clean'''+self.base+'''.csh '''+CleanArgs]

    #########
    # outputs
    #########
    self.outputs = {}
    self.outputs['obs'] = {}
    self.outputs['obs']['members'] = ObsEnsemble(dt)
    for mm in range(1, NN+1, 1): 
      workDir = self.workDir+'/'+subDirectory+memFmt.format(mm)+'/{{thisCycleDate}}'
      if dt > 0 or 'fc' in subDirectory:
        workDir += '/'+dtStr+'hr'

      self.outputs['obs']['members'].append({
        'directory': workDir+'/'+Observations.OutDBDir,
        'observers': self['observers'],
      })

  def export(self):
    '''
    export for use outside python
    '''
    ###########################
    # update tasks/dependencies
    ###########################
    self._dependencies = self.TM.updateDependencies(self._dependencies)
    self._tasks = self.TM.updateTasks(self._tasks, self._dependencies)

    super().export()
    return