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

    if members.n > 1:
      memFmt = '/mem{:03d}'
    else:
      memFmt = ''

    self.mesh = mesh
    assert self.mesh == coldIC.mesh(), 'coldIC must be on same mesh as forecast'
    assert self.mesh == warmIC.mesh(), 'warmIC must be on same mesh as forecast'

    self.model = model

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
      'retry': {'t': str},
      'baseSeconds': {'t': int},
      'secondsPerForecastHR': {'t': int},
      'nodes': {'t': int},
      'PEPerNode': {'t': int},
      'memory': {'def': '45GB', 't': str},
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
      'email': {'def': True, 't': bool},
    }
    # store job for ExtendedForecast to re-use
    self.job = Resource(self._conf, attr, ('job', mesh.name))
    self.job._set('seconds', self.job['baseSeconds'] + self.job['secondsPerForecastHR'] * lengthHR)
    task = TaskLookup[hpc.system](self.job)

    # MeanBackground
    attr = {
      'seconds': {'def': 300},
      'nodes': {'def': 1, 't': int},
      'PEPerNode': {'def': 36, 't': int},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    meanjob = Resource(self._conf, attr, ('job', 'meanbackground'))
    meantask = TaskLookup[hpc.system](meanjob)


    self.groupName = 'ForecastFamily'
    self._tasks = ['''
  [['''+self.groupName+''']]
  [[ColdForecast]]
    inherit = '''+self.groupName+'''
'''+task.job()+task.directives()+'''

  [[Forecast]]
    inherit = '''+self.groupName+'''
'''+task.job()+task.directives()+'''

  [[ForecastFinished]]
    inherit = '''+self.groupName+'''

  ## post mean background (if needed)
  [[MeanBackground]]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/bin/MeanBackground.csh
'''+meantask.job()+meantask.directives()]

    for mm in range(1, members.n+1, 1):
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
        self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm),
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
        self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm),
        warmIC[mm-1].directory(),
        warmIC[mm-1].prefix(),
      ]
      WarmArgs = ' '.join(['"'+str(a)+'"' for a in args])

      self._tasks += ['''
  [[ColdForecast'''+str(mm)+''']]
    inherit = ColdForecast, BATCH
    script = $origin/bin/Forecast.csh '''+ColdArgs+'''
  [[Forecast'''+str(mm)+''']]
    inherit = Forecast, BATCH
    script = $origin/bin/Forecast.csh '''+WarmArgs]

    self._dependencies += ['''
        # ensure there is a valid sea-surface update file before forecast
        {{PrepareSeaSurfaceUpdate}} => Forecast

        # all members must succeed in order to proceed
        Forecast:succeed-all => ForecastFinished''']

    ##################
    # outputs and post
    ##################
    self.outputs = {}
    self.outputs['state'] = {}

    previousForecast = 'ForecastFinished[-PT'+str(window)+'H]'
    self.__post = []

    postconf = {
      'tasks': self['post'],
      'label': 'bg',
      'valid tasks': ['verifyobs', 'verifymodel'],
      'verifyobs': {
        'sub directory': 'bg',
        'dependencies': [previousForecast, '{{PrepareObservations}}'],
      },
      'verifymodel': {
        'sub directory': 'bg',
        'dependencies': [previousForecast, '{{PrepareExternalAnalysisOuter}}'],
      },
    }

    # mean case when members.n > 1
    if members.n > 1:
      self._dependencies += ['''
        '''+previousForecast+''' => MeanBackground''']

      # store original conf values
      pp = deepcopy(postconf)

      # re-prupose for mean bg tasks
      for k in ['verifyobs', 'verifymodel']:
        postconf[k]['dependencies'] += ['MeanBackground']
        postconf[k]['member multiplier'] = members.n
      postconf['verifymodel']['dependencies'] += [DA.finished]
      postconf['verifymodel']['followon'] = [DA.clean]

      self.outputs['state']['mean'] = StateEnsemble(self.mesh)
      # TODO: get this file name from Variational component during export
      # actually an output of MeanBackground, which could have its own application class...
      self.outputs['state']['mean'].append({
        'directory': Variational.workDir+'/{{thisCycleDate}}/'+Variational.backgroundPrefix+'/mean',
        'prefix': self.forecastPrefix,
      })

      self.__post.append(Post(
        postconf, config,
        hpc, mesh, model,
        states = self.outputs['state']['mean'],
      ))

      # restore original conf values
      postconf = deepcopy(pp)

      # only need verifyobs from individual ensemble members; used to calculate ensemble spread
      if 'verifyobs' in postconf['tasks']:
        postconf['tasks'] = ['verifyobs']
      else:
        postconf['tasks'] = []

    # member case (mean case when members.n == 1)
    self.outputs['state']['members'] = StateEnsemble(self.mesh)
    for mm in range(1, members.n+1, 1):
      self.outputs['state']['members'].append({
        'directory': self.workDir+'/{{prevCycleDate}}'+memFmt.format(mm),
        'prefix': self.forecastPrefix,
      })

    self.__post.append(Post(
      postconf, config,
      hpc, mesh, model,
      states = self.outputs['state']['members'],
    ))

  def export(self, components):
    for p in self.__post:
      p.export(components)
    super().export(components)
