#!/usr/bin/env python3

from initialize.components.ExternalAnalyses import ExternalAnalyses
from initialize.components.Forecast import Forecast
from initialize.components.HPC import HPC
#from initialize.components.Mesh import Mesh
from initialize.components.Members import Members
from initialize.components.Model import Model
from initialize.components.Observations import Observations

from initialize.Component import Component
from initialize.data.StateEnsemble import StateEnsemble, State
from initialize.Resource import Resource
from initialize.util.Post import Post
from initialize.util.Task import TaskFactory

class ExtendedForecast(Component):
  workDir = 'ExtendedFC'

  variablesWithDefaults = {
    # length of verification extended forecasts
    'lengthHR': [240, int],

    # interval between OMF verification times of an individual forecast
    'outIntervalHR': [12, int],

    # UTC times to run extended forecast from mean analysis
    # formatted as comma-separated string, e.g., T00,T06,T12,T18
    'meanTimes': ['T00,T12', str],

    # UTC times to run ensemble of extended forecasts
    # formatted as comma-separated string, e.g., T00,T06,T12,T18
    'ensTimes': ['T00', str],

    ## post
    # list of tasks for Post
    'post': [['verifyobs', 'verifymodel'], list]
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
    members:Members,
    forecast:Forecast,
    externalanalyses:ExternalAnalyses,
    observations:Observations,
    extAnaIC:StateEnsemble,
    meanAnaIC:State,
    ensAnaIC:StateEnsemble,
  ):
    super().__init__(config)

    self.mesh = forecast.mesh
    assert self.mesh == extAnaIC.mesh(), 'extAnaIC must be on same mesh as extended forecast'
    assert self.mesh == meanAnaIC.mesh(), 'meanAnaIC must be on same mesh as extended forecast'
    assert self.mesh == ensAnaIC.mesh(), 'ensAnaIC must be on same mesh as extended forecast'

    ###################
    # derived variables
    ###################

    lengthHR = self['lengthHR']
    outIntervalHR = self['outIntervalHR']
    self._set('extMeanTimes', self['meanTimes'])
    self._set('extEnsTimes', self['ensTimes'])
    self._set('extMeanTimesList', self['meanTimes'].split(','))
    self._set('extEnsTimesList', self['ensTimes'].split(','))

    EnsVerifyMembers = range(1, members.n+1, 1)
    self._set('EnsVerifyMembers', EnsVerifyMembers)

    extLengths = range(0, lengthHR+outIntervalHR, outIntervalHR)
    self._set('extIntervHR', outIntervalHR)
    self._set('extLengths', extLengths)
    #self._set('nExtOuts', len(extLengths))

    self._cylcVars = ['extMeanTimes', 'extEnsTimes',
      'extMeanTimesList', 'extEnsTimesList',
      'EnsVerifyMembers', 'extIntervHR', 'extLengths']#, 'nExtOuts']

    ########################
    # tasks and dependencies
    ########################
    # job settings

    # ExtendedFCBase
    job = forecast.job
    job._set('seconds', job['baseSeconds'] + job['secondsPerForecastHR'] * lengthHR)
    job._set('queue', hpc['NonCriticalQueue'])
    job._set('account', hpc['NonCriticalAccount'])
    fctask = TaskFactory[hpc.system](job)

    # MeanAnalysis
    attr = {
      'seconds': {'def': 300},
      'nodes': {'def': 1, 't': int},
      'PEPerNode': {'def': 36, 't': int},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    meanjob = Resource(self._conf, attr, ('job', 'meananalysis'))
    meantask = TaskFactory[hpc.system](meanjob)

    args = [
      1,
      lengthHR,
      outIntervalHR,
      False,
      self.mesh.name,
      False,
      False,
      False,
      self.workDir+'/{{thisCycleDate}}/mean',
      extAnaIC[0].directory(),
      extAnaIC[0].prefix(),
    ]
    extAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

    args = [
      1,
      lengthHR,
      outIntervalHR,
      False,
      self.mesh.name,
      True,
      False,
      False,
      self.workDir+'/{{thisCycleDate}}/mean',
      meanAnaIC.directory(),
      meanAnaIC.prefix(),
    ]
    meanAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

    self.groupName = self.__class__.__name__
    self._tasks = ['''
  [['''+self.groupName+''']]
'''+fctask.job()+fctask.directives()+'''

  ## from external analysis
  [[ExtendedFCFromExternalAnalysis]]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/Forecast.csh '''+extAnaArgs+'''

  ## from mean analysis (including single-member deterministic)
  [[MeanAnalysis]]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/MeanAnalysis.csh
'''+meantask.job()+meantask.directives()+'''
  [[ExtendedMeanFC]]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/Forecast.csh '''+meanAnaArgs+'''


  [[ExtendedForecastFinished]]
    inherit = '''+self.groupName+'''

  ## from ensemble of analyses
  [[ExtendedEnsFC]]
    inherit = '''+self.groupName]

    memFmt = '/mem{:03d}'
    for mm in EnsVerifyMembers:
      args = [
        mm,
        lengthHR,
        outIntervalHR,
        False,
        self.mesh.name,
        True,
        False,
        False,
        self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm),
        ensAnaIC[mm-1].directory(),
        ensAnaIC[mm-1].prefix(),
      ]
      ensAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

      self._tasks += ['''
  [[ExtendedFC'''+str(mm)+''']]
    inherit = ExtendedEnsFC, BATCH
    script = $origin/applications/Forecast.csh '''+ensAnaArgs]

    ##################
    # outputs and post
    ##################
    self.outputs = {}
    self.outputs['state'] = {}
    self.outputs['state']['members'] = {}
    self.outputs['state']['mean'] = {}

    posttasks = self['post']
    postconf = {
      'tasks': posttasks,
      'followon': {}
    }
    validTasks = ['verifyobs', 'verifymodel']

    self.__post = []

    prepObsTasks = observations['PrepareObservationsTasks']
    prepEATasks = externalanalyses['PrepareExternalAnalysisTasksOuter']

    for dt in extLengths:

      dtStr = str(dt)

      if dt == 0:
        success = ':succeed-all'
      else:
        success = ''

      taskSuffix = '-'+dtStr+'hr'+success
      prepObs = (taskSuffix+" => ").join(prepObsTasks)+taskSuffix
      prepEA = (taskSuffix+" => ").join(prepEATasks)+taskSuffix

      postconf['dependencies'] = {
        'verifyobs': ['ExtendedForecastFinished', prepObs],
        'verifymodel': ['ExtendedForecastFinished', prepEA],
      }

      # note: only duration (dt) varies across output state

      # ensemble forecasts
      self.outputs['state']['members'][dtStr] = StateEnsemble(self.mesh, dt)
      for mm in range(1, members.n+1, 1):
        self.outputs['state']['members'][dtStr].append({
          'directory': self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm),
          'prefix': Forecast.forecastPrefix,
        })

      postconf['label'] = ensfc
      self.__post.append(Post(
        postconf, config,
        validTasks,
        hpc, mesh, model,
        states = self.outputs['state']['members'][dtStr],
      ))

      # mean forecast
      self.outputs['state']['mean'][dtStr] = StateEnsemble(self.mesh, dt)
      self.outputs['state']['mean'][dtStr].append({
          'directory': self.workDir+'/{{thisCycleDate}}/mean',
          'prefix': Forecast.forecastPrefix,
      })

      postconf['label'] = fc
      self.__post.append(Post(
        postconf, config,
        validTasks,
        hpc, mesh, model,
        states = self.outputs['state']['mean'][dtStr],
      ))

  def export(self, components):
    for p in self.__post:
      p.export(components)
    super().export(components)
