#!/usr/bin/env python3

from copy import deepcopy

from initialize.applications.DA import DA
from initialize.applications.Members import Members
from initialize.applications.Variational import Variational

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

from initialize.data.Model import Model, Mesh
from initialize.data.StateEnsemble import StateEnsemble

from initialize.framework.HPC import HPC
from initialize.framework.Workflow import Workflow

from initialize.post.Post import Post

class Forecast(Component):
  defaults = 'scenarios/defaults/forecast.yaml'
  workDir = 'CyclingFC'
#  RSTFilePrefix = 'restart'
#  ICFilePrefix = 'mpasin'
#
  forecastPrefix = 'mpasout'
#  fcDir = 'fc'
#  DIAGFilePrefix = 'diag'

  variablesWithDefaults = {
    ## updateSea
    # whether to update surface fields before a forecast (e.g., sst, xice)
    'updateSea': [True, bool],

    ## IAU
    # whether to use incremental analysis update
    'IAU': [False, bool],

    ## post
    # list of tasks for Post
    'post': [['verifyobs', 'verifymodel'], list]
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
    mesh:Mesh,
    members:Members,
    model:Model,
    workflow:Workflow,
    coldIC:StateEnsemble,
    warmIC:StateEnsemble,
  ):
    super().__init__(config)
    self.__globalConf = config
    self.mesh = mesh
    self.model = model
    self.NN = members.n
    self.memFmt = members.memFmt

    assert mesh == coldIC.mesh(), 'coldIC must be on same mesh as forecast'
    assert mesh == warmIC.mesh(), 'warmIC must be on same mesh as forecast'


    ###################
    # derived variables
    ###################

    IAU = self['IAU']

    window = workflow['CyclingWindowHR']
    if IAU:
      outIntervalHR = window // 2
      lengthHR = 3 * outIntervalHR
    else:
      outIntervalHR = window
      lengthHR = window

    ########################
    # tasks and dependencies
    ########################
    # job settings
    updateSea = self['updateSea']

    attr = {
      'retry': {'typ': str},
      'baseSeconds': {'typ': int},
      'secondsPerForecastHR': {'typ': int},
      'nodes': {'typ': int},
      'PEPerNode': {'typ': int},
      'memory': {'def': '45GB', 'typ': str},
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
      'email': {'def': True, 'typ': bool},
    }
    # store job for ExtendedForecast to re-use
    self.job = Resource(self._conf, attr, ('job', mesh.name))
    self.job._set('seconds', self.job['baseSeconds'] + self.job['secondsPerForecastHR'] * lengthHR)
    task = TaskLookup[hpc.system](self.job)

    # MeanBackground
    attr = {
      'seconds': {'def': 300},
      'nodes': {'def': 1, 'typ': int},
      'PEPerNode': {'def': 36, 'typ': int},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    meanjob = Resource(self._conf, attr, ('job', 'meanbackground'))
    meantask = TaskLookup[hpc.system](meanjob)


    self.group = 'ForecastFamily'
    self._tasks = ['''
  [['''+self.group+''']]
  [[Cold'''+self.base+''']]
    inherit = '''+self.group+'''
'''+task.job()+task.directives()+'''

  [['''+self.base+''']]
    inherit = '''+self.group+'''
'''+task.job()+task.directives()+'''

  [['''+self.finished+''']]
    inherit = '''+self.group+'''

  ## post mean background (if needed)
  [[MeanBackground]]
    inherit = '''+self.group+''', BATCH
    script = $origin/bin/MeanBackground.csh
'''+meantask.job()+meantask.directives()]

    for mm in range(1, self.NN+1, 1):
      # ColdArgs explanation
      # IAU (False) cannot be used until 1 cycle after DA analysis
      # DACycling (False), IC ~is not~ a DA analysis for which re-coupling is required
      # DeleteZerothForecast (True), not used anywhere else in the workflow
      # updateSea (False) is not needed since the IC is already an external analysis
      args = [
        1,
        lengthHR,
        outIntervalHR,
        False,
        mesh.name,
        False,
        True,
        False,
        self.workDir+'/{{thisCycleDate}}'+self.memFmt.format(mm),
        coldIC[0].directory(),
        coldIC[0].prefix(),
      ]
      ColdArgs = ' '.join(['"'+str(a)+'"' for a in args])


      # WarmArgs explanation
      # DACycling (True), IC ~is~ a DA analysis for which re-coupling is required
      # DeleteZerothForecast (True), not used anywhere else in the workflow
      args = [
        mm,
        lengthHR,
        outIntervalHR,
        IAU,
        mesh.name,
        True,
        True,
        updateSea,
        self.workDir+'/{{thisCycleDate}}'+self.memFmt.format(mm),
        warmIC[mm-1].directory(),
        warmIC[mm-1].prefix(),
      ]
      WarmArgs = ' '.join(['"'+str(a)+'"' for a in args])

      self._tasks += ['''
  [[Cold'''+self.base+str(mm)+''']]
    inherit = Cold'''+self.base+''', BATCH
    script = $origin/bin/'''+self.base+'''.csh '''+ColdArgs+'''
  [['''+self.base+str(mm)+''']]
    inherit = '''+self.base+''', BATCH
    script = $origin/bin/'''+self.base+'''.csh '''+WarmArgs]

    # {{ForecastTimes}} dependencies only, not the R1 cycle
    self._dependencies += ['''
        # ensure there is a valid sea-surface update file before forecast
        {{PrepareSeaSurfaceUpdate}} => '''+self.base+'''

        # all members must succeed in order to proceed
        '''+self.base+''':succeed-all => '''+self.finished]

    self.previousForecast = self.finished+'[-PT'+str(window)+'H]'

    self.postconf = {
      'tasks': self['post'],
      'label': 'bg',
      'valid tasks': ['verifyobs', 'verifymodel'],
      'verifyobs': {
        'hpc': hpc,
        'mesh': mesh,
        'model': model,
        'sub directory': 'bg',
        'dependencies': [self.previousForecast, '{{PrepareObservations}}'],
      },
      'verifymodel': {
        'hpc': hpc,
        'mesh': mesh,
        'sub directory': 'bg',
        'dependencies': [self.previousForecast, '{{PrepareExternalAnalysisOuter}}'],
      },
    }

    #########
    # outputs
    #########

    self.outputs = {}
    self.outputs['state'] = {}

    self.outputs['state']['members'] = StateEnsemble(mesh)
    for mm in range(1, self.NN+1, 1):
      self.outputs['state']['members'].append({
        'directory': self.workDir+'/{{prevCycleDate}}'+self.memFmt.format(mm),
        'prefix': self.forecastPrefix,
      })

    self.outputs['state']['mean'] = StateEnsemble(mesh)
    # TODO: get this file name from Variational component during export
    # actually an output of MeanBackground, which could have its own application class...
    self.outputs['state']['mean'].append({
      'directory': Variational.workDir+'/{{thisCycleDate}}/'+Variational.backgroundPrefix+'/mean',
      'prefix': self.forecastPrefix,
    })


  def export(self, da:DA):

    ######
    # post
    ######
    __post = []

    # mean case when self.NN > 1
    if self.NN > 1:
      self._dependencies += ['''
        '''+self.previousForecast+''' => MeanBackground''']

      # store original conf values
      pp = deepcopy(self.postconf)

      # re-purpose for mean bg tasks
      for k in ['verifyobs', 'verifymodel']:
        self.postconf[k]['dependencies'] += ['MeanBackground']
        self.postconf[k]['member multiplier'] = self.NN
        self.postconf[k]['states'] = self.outputs['state']['mean']

      # mean-state model verification also diagnoses posterior ensemble spread
      self.postconf['verifymodel']['dependencies'] += [da.finished]
      self.postconf['verifymodel']['followon'] = [da.clean]

      __post.append(Post(self.postconf, self.__globalConf))

      # restore original conf values
      self.postconf = deepcopy(pp)

      # only need verifyobs from individual ensemble members; used to calculate ensemble spread
      if 'verifyobs' in self.postconf['tasks']:
        self.postconf['tasks'] = ['verifyobs']
      else:
        self.postconf['tasks'] = []

    # member case (mean case when NN == 1)
    for k in ['verifyobs', 'verifymodel']:
      self.postconf[k]['states'] = self.outputs['state']['members']

    __post.append(Post(self.postconf, self.__globalConf))

    ########
    # export
    ########
    for p in __post:
      p.export()
    super().export()
