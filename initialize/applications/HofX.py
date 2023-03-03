#!/usr/bin/env python3

from initialize.framework.HPC import HPC

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

from initialize.data.Model import Model, Mesh
from initialize.data.Observations import Observations
from initialize.data.ObsEnsemble import ObsEnsemble
from initialize.data.StateEnsemble import StateEnsemble

class HofX(Component):
  defaults = 'scenarios/defaults/hofx.yaml'

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
      'gnssroref',
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

  WorkDir = 'Verification'

  def __init__(self,
    config:Config,
    localConf:dict,
    hpc:HPC,
    mesh:Mesh,
    model:Model,
    states:StateEnsemble,
  ):
    super().__init__(config)

    base = self.__class__.__name__

    subDirectory = str(localConf['sub directory'])
    dependencies = list(localConf.get('dependencies', []))
    followon = list(localConf.get('followon', []))

    dt = states.duration()
    dtStr = str(dt)
    NN = len(states)

    if NN > 1:
      memFmt = '/mem{:03d}'
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

    # job settings
    attr = {
      'retry': {'t': str},
      'seconds': {'t': int},
      'nodes': {'t': int},
      'PEPerNode': {'t': int},
      'memory': {'def': '45GB', 't': str},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    job = Resource(self._conf, attr, ('job', mesh.name))
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
      workDir = self.WorkDir+'/'+subDirectory+'/{{thisCycleDate}}'+memFmt.format(mm+1)
      if dt > 0 or 'fc' in subDirectory:
        workDir += '/'+dtStr+'hr'

      args = [
        dt,
        self.lower,
        workDir,
        6, # window (hr); TODO: to be provided by parent
      ]
      PrepJEDIArgs = ' '.join(['"'+str(a)+'"' for a in args])

      args = [
        mm+1,
        dt,
        workDir,
        state.directory(),
        state.prefix(),
      ]
      HofXArgs = ' '.join(['"'+str(a)+'"' for a in args])

      args = [
        dt,
        workDir,
      ]
      CleanArgs = ' '.join(['"'+str(a)+'"' for a in args])

      if NN > 1:
        HofXTask = self.groupName+'_'+str(mm+1)
        CleanTask = self.clean+'_'+str(mm+1)
      else:
        HofXTask = self.groupName+'_MEAN'
        CleanTask = self.clean+'_MEAN'

      self._tasks += ['''
  [['''+HofXTask+''']]
    inherit = '''+self.groupName+''', BATCH
    env-script = cd {{mainScriptDir}}; ./bin/PrepJEDI.csh '''+PrepJEDIArgs+'''
    script = $origin/bin/'''+base+'''.csh '''+HofXArgs+'''
  [['''+CleanTask+''']]
    inherit = '''+self.clean+''', Clean
    script = $origin/bin/Clean'''+base+'''.csh '''+CleanArgs]

      self._dependencies += ['''
        '''+HofXTask+''' => '''+CleanTask]

    #########
    # outputs
    #########
    self.outputs = {}
    self.outputs['obs'] = {}
    self.outputs['obs']['members'] = ObsEnsemble(dt)
    for mm in range(1, NN+1, 1): 
      workDir = self.WorkDir+'/'+subDirectory+'/{{thisCycleDate}}'+memFmt.format(mm)
      if dt > 0 or 'fc' in subDirectory:
        workDir += '/'+dtStr+'hr'

      self.outputs['obs']['members'].append({
        'directory': workDir+'/'+Observations.OutDBDir,
        'observers': self['observers'],
      })

  def export(self, components):
    '''
    export for use outside python
    '''
    self._exportVarsToCsh()
    self._exportVarsToCylc()
    return
