#!/usr/bin/env python3

from initialize.applications.Forecast import Forecast
from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.Model import Model
from initialize.data.Observations import Observations
from initialize.data.StateEnsemble import StateEnsemble, State

from initialize.framework.HPC import HPC

from initialize.post.Post import Post

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
    fc:Forecast,
    ea:ExternalAnalyses,
    obs:Observations,
    extAnaIC:StateEnsemble,
    meanAnaIC:State,
    ensAnaIC:StateEnsemble,
  ):
    super().__init__(config)
    self.NN = members.n
    self.memFmt = members.memFmt

    assert fc.mesh == extAnaIC.mesh(), 'extAnaIC must be on same mesh as extended forecast'
    assert fc.mesh == meanAnaIC.mesh(), 'meanAnaIC must be on same mesh as extended forecast'
    assert fc.mesh == ensAnaIC.mesh(), 'ensAnaIC must be on same mesh as extended forecast'

    ###################
    # derived variables
    ###################

    lengthHR = self['lengthHR']
    outIntervalHR = self['outIntervalHR']
    self._set('extMeanTimes', self['meanTimes'])
    self._set('extEnsTimes', self['ensTimes'])
    self._set('extMeanTimesList', self['meanTimes'].split(','))
    self._set('extEnsTimesList', self['ensTimes'].split(','))

    EnsVerifyMembers = range(1, self.NN+1, 1)
    self._set('EnsVerifyMembers', EnsVerifyMembers)

    extLengths = range(0, lengthHR+outIntervalHR, outIntervalHR)
    self._set('extIntervHR', outIntervalHR)
    self._set('extLengths', extLengths)
    #self._set('nExtOuts', len(extLengths))

    self._cylcVars = ['extMeanTimes', 'extEnsTimes']

    ########################
    # tasks and dependencies
    ########################
    # job settings

    # ExtendedFCBase
    job = fc.job
    job._set('seconds', job['baseSeconds'] + job['secondsPerForecastHR'] * lengthHR)
    job._set('queue', hpc['NonCriticalQueue'])
    job._set('account', hpc['NonCriticalAccount'])
    fctask = TaskLookup[hpc.system](job)

    # MeanAnalysis
    attr = {
      'seconds': {'def': 300},
      'nodes': {'def': 1, 'typ': int},
      'PEPerNode': {'def': 36, 'typ': int},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    meanjob = Resource(self._conf, attr, ('job', 'meananalysis'))
    meantask = TaskLookup[hpc.system](meanjob)

    args = [
      1,
      lengthHR,
      outIntervalHR,
      False,
      fc.mesh.name,
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
      fc.mesh.name,
      True,
      False,
      False,
      self.workDir+'/{{thisCycleDate}}/mean',
      meanAnaIC.directory(),
      meanAnaIC.prefix(),
    ]
    meanAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

    self._tasks = ['''
  [['''+self.group+''']]
'''+fctask.job()+fctask.directives()+'''

  ## from external analysis
  [[ExtendedFCFromExternalAnalysis]]
    inherit = '''+self.group+''', BATCH
    script = $origin/bin/'''+fc.base+'''.csh '''+extAnaArgs+'''

  ## from mean analysis (including single-member deterministic)
  [[MeanAnalysis]]
    inherit = '''+self.group+''', BATCH
    script = $origin/bin/MeanAnalysis.csh
'''+meantask.job()+meantask.directives()+'''
  [[ExtendedMeanFC]]
    inherit = '''+self.group+''', BATCH
    script = $origin/bin/'''+fc.base+'''.csh '''+meanAnaArgs+'''


  [[ExtendedForecastFinished]]
    inherit = '''+self.group+'''

  ## from ensemble of analyses
  [[ExtendedEnsFC]]
    inherit = '''+self.group]

    for mm in EnsVerifyMembers:
      args = [
        mm,
        lengthHR,
        outIntervalHR,
        False,
        fc.mesh.name,
        True,
        False,
        False,
        self.workDir+'/{{thisCycleDate}}'+self.memFmt.format(mm),
        ensAnaIC[mm-1].directory(),
        ensAnaIC[mm-1].prefix(),
      ]
      ensAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

      self._tasks += ['''
  [[ExtendedFC'''+str(mm)+''']]
    inherit = ExtendedEnsFC, BATCH
    script = $origin/bin/'''+fc.base+'''.csh '''+ensAnaArgs]

    ##################
    # outputs and post
    ##################
    self.outputs = {}
    self.outputs['state'] = {}
    self.outputs['state']['members'] = {}
    self.outputs['state']['mean'] = {}

    postconf = {
      'tasks': self['post'],
      'valid tasks': ['verifyobs', 'verifymodel'],
      'verifyobs': {
        'hpc': hpc,
        'mesh': fc.mesh,
        'model': fc.model,
        'sub directory': 'fc',
      },
      'verifymodel': {
        'hpc': hpc,
        'mesh': fc.mesh,
        'sub directory': 'fc',
      },
    }

    self.__post = []

    prepObsTasks = obs['PrepareObservationsTasks']
    prepEATasks = ea['PrepareExternalAnalysisTasksOuter']

    for dt in extLengths:

      dtStr = str(dt)

      if dt == 0:
        success = ':succeed-all'
      else:
        success = ''

      taskSuffix = '-'+dtStr+'hr'+success
      prepObs = (taskSuffix+" => ").join(prepObsTasks)+taskSuffix
      prepEA = (taskSuffix+" => ").join(prepEATasks)+taskSuffix

      postconf['verifyobs']['dependencies'] = ['ExtendedForecastFinished', prepObs]
      postconf['verifymodel']['dependencies'] = ['ExtendedForecastFinished', prepEA]

      # note: only duration (dt) varies across output state

      # ensemble forecasts
      self.outputs['state']['members'][dtStr] = StateEnsemble(fc.mesh, dt)
      for mm in range(1, self.NN+1, 1):
        self.outputs['state']['members'][dtStr].append({
          'directory': self.workDir+'/{{thisCycleDate}}'+self.memFmt.format(mm),
          'prefix': Forecast.forecastPrefix,
        })

      for k in ['verifyobs', 'verifymodel']:
        postconf[k]['states'] = self.outputs['state']['members'][dtStr]

      postconf['label'] = 'ensfc'
      self.__post.append(Post(postconf, config))

      # mean forecast
      self.outputs['state']['mean'][dtStr] = StateEnsemble(fc.mesh, dt)
      self.outputs['state']['mean'][dtStr].append({
        'directory': self.workDir+'/{{thisCycleDate}}/mean',
        'prefix': Forecast.forecastPrefix,
      })

      for k in ['verifyobs', 'verifymodel']:
        postconf[k]['states'] = self.outputs['state']['mean'][dtStr]

      postconf['label'] = 'fc'
      self.__post.append(Post(postconf, config))

  def export(self):
    for p in self.__post:
      p.export()
    super().export()
