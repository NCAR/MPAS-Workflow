#!/usr/bin/env python3

from initialize.components.DA import DA
from initialize.components.HPC import HPC
from initialize.components.Mesh import Mesh
from initialize.components.Members import Members
from initialize.components.Model import Model
from initialize.components.Variational import Variational

from initialize.Component import Component
from initialize.Config import Config
from initialize.data.StateEnsemble import StateEnsemble
from initialize.Resource import Resource
from initialize.util.Post import Post
from initialize.util.Task import TaskFactory

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

    ###################
    # derived variables
    ###################

    IAU = self['IAU']

    if IAU:
      outIntervalHR = workflow['CyclingWindowHR'] // 2
      lengthHR = 3 * outIntervalHR
    else:
      outIntervalHR = workflow['CyclingWindowHR']
      lengthHR = workflow['CyclingWindowHR']

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
    task = TaskFactory[hpc.system](self.job)

    # MeanBackground
    attr = {
      'seconds': {'def': 300},
      'nodes': {'def': 1, 't': int},
      'PEPerNode': {'def': 36, 't': int},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    meanjob = Resource(self._conf, attr, ('job', 'meanbackground'))
    meantask = TaskFactory[hpc.system](meanjob)


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
    script = $origin/applications/MeanBackground.csh
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
    script = $origin/applications/Forecast.csh '''+ColdArgs+'''
  [[Forecast'''+str(mm)+''']]
    inherit = Forecast, BATCH
    script = $origin/applications/Forecast.csh '''+WarmArgs]

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

    previousForecast = 'ForecastFinished[-PT'+workflow['CyclingWindowHR']+'H]'
    self.__post = []

    posttasks = self['post']
    postconf = {
      'tasks': posttasks,
      'label': 'bg',
      'dependencies': {
        'verifyobs': [previousForecast, '{{PrepareObservations}}'],
        'verifymodel': [previousForecast, '{{PrepareExternalAnalysisOuter}}'],
      }
      'followon': {}
    }

    validTasks = ['verifyobs', 'verifymodel']

    # mean case when members.n > 1
    if members.n > 1:
      self._dependencies += ['''
        '''+previousForecast+''' => MeanBackground''']

      # store original conf values
      ll = postconf['label']
      dd = deepcopy(postconf['dependencies'])
      ff = deepcopy(postconf['followon'])

      # override for bgmean tasks
      postconf['label'] = 'bgmean'
      for k in ['verifyobs', 'verifymodel']:
        postconf['dependencies'][k] += ['MeanBackground']
      postconf['dependencies']['verifyobs'] += ['HofX'+ll.upper()]
      postconf['dependencies']['verifymodel'] += [DA.finished]
      postconf['followon']['verifymodel'] = [DA.clean]

      self.outputs['state']['mean'] = StateEnsemble(self.mesh)
      self.outputs['state']['mean'].append({
        'directory': Variational.workDir+'/{{thisCycleDate}}/mean',
        'prefix': Variational.backgroundPrefix,
      })

      if len(self.outputs['state']['members']) > 1:
        self.__post.append(Post(
          postconf, config,
          validTasks,
          hpc, mesh, model, members.n,
          states = self.outputs['state']['mean'],
        ))

      # restore original conf values
      postconf['label'] = ll
      postconf['dependencies'] = dd
      postconf['followon'] = ff

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
      validTasks,
      hpc, mesh, model,
      states = self.outputs['state']['members'],
    ))

  def export(self, components):
    for p in self.__post:
      p.export(components)
    super().export(components)
