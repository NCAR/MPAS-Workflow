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
from initialize.framework.Workflow import Workflow

from initialize.post.Post import Post

class ExtendedForecast(Component):
  workDir = 'ExtendedFC'

  variablesWithDefaults = {
    # length of verification extended forecasts
    'lengthHR': [240, int],

    # interval between OMF verification times of an individual forecast
    'outIntervalHR': [12, int],

    # UTC times to run extended forecast from mean or single analysis
    # formatted as comma-separated string, e.g., T00,T06,T12,T18
    # note: must be supplied in order to do single-state verification
    'meanTimes': [None, str],

    # UTC times to run ensemble of extended forecasts
    # formatted as comma-separated string, e.g., T00,T06,T12,T18
    # note: must be supplied in order to do ensemble-state verification
    'ensTimes': [None, str],

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
    self.__globalConf = config
    super().__init__(config)
    self.NN = members.n
    self.memFmt = members.memFmt
    self.hpc = hpc
    self.fc = fc
    self.ea = ea
    self.obs = obs

    assert fc.mesh == extAnaIC.mesh(), 'extAnaIC must be on same mesh as extended forecast'
    assert fc.mesh == meanAnaIC.mesh(), 'meanAnaIC must be on same mesh as extended forecast'
    assert fc.mesh == ensAnaIC.mesh(), 'ensAnaIC must be on same mesh as extended forecast'

    ###################
    # derived variables
    ###################

    lengthHR = self['lengthHR']
    outIntervalHR = self['outIntervalHR']
    extLengths = range(0, lengthHR+outIntervalHR, outIntervalHR)
    self._set('extLengths', extLengths)
    self.ensVerifyMembers = range(1, self.NN+1, 1)

    #########################################
    # group base task and args to executables
    #########################################
    # job settings for self.TM.execute
    job = fc.job
    job._set('seconds', job['baseSeconds'] + job['secondsPerForecastHR'] * lengthHR)
    job._set('queue', hpc['NonCriticalQueue'])
    job._set('account', hpc['NonCriticalAccount'])
    fctask = TaskLookup[hpc.system](job)

    self._tasks += ['''
  [['''+self.TM.execute+''']]
'''+fctask.job()+fctask.directives()]

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
    self.extAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

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
    self.meanAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

    self.ensAnaArgs = {}
    for mm in self.ensVerifyMembers:
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
      self.ensAnaArgs[str(mm)] = ' '.join(['"'+str(a)+'"' for a in args])

  def export(self,
    dependency:str,
    singleForecastType:str='external',
    activateEnsemble:bool=False,
  ):
    '''
    dependency: single task on which extended forecast tasks depend
    singleForecastType: either internal or external
    activateEnsemble: whether to activate ensemble extended forecasts (False by default)
    '''

    assert singleForecastType in ['internal','external'], (
     'ExtendedForecast.export: incorrect singleForecastType => '+singleForecastType)

    doSingle = (self['meanTimes'] is not None)
    doEnsemble = (self['ensTimes'] is not None and self.NN > 1 and activateEnsemble)

    self._tasks += self.TM.tasks()

    ##################
    # outputs and post
    ##################
    self.outputs = {}
    self.outputs['state'] = {}
    self.outputs['state']['members'] = {}
    self.outputs['state']['mean'] = {}

    postconf = {
      'tasks': self['post'],
      'valid tasks': ['hofx', 'verifyobs', 'verifymodel'],
      'verifyobs': {
        'hpc': self.hpc,
        'mesh': self.fc.mesh,
        'model': self.fc.model,
        'sub directory': 'fc',
      },
      'verifymodel': {
        'hpc': self.hpc,
        'mesh': self.fc.mesh,
        'sub directory': 'fc',
      },
    }

    meanpost = []
    enspost = []

    prepObsTasks = self.obs['PrepareObservationsTasks']
    prepEATasks = self.ea['PrepareExternalAnalysisTasksOuter']

    for dt in self['extLengths']:

      dtStr = str(dt)

      if dt == 0:
        success = ':succeed-all'
      else:
        success = ''

      taskSuffix = '-'+dtStr+'hr'+success
      prepObs = (taskSuffix+" => ").join(prepObsTasks)+taskSuffix
      prepEA = (taskSuffix+" => ").join(prepEATasks)+taskSuffix

      postconf['verifyobs']['dependencies'] = [self.TM.finished, prepObs]
      postconf['verifymodel']['dependencies'] = [self.TM.finished, prepEA]

      # note: only duration (dt) varies across output state

      # ensemble forecasts
      if doEnsemble:
        self.outputs['state']['members'][dtStr] = StateEnsemble(self.fc.mesh, dt)
        for mm in self.ensVerifyMembers:
          self.outputs['state']['members'][dtStr].append({
            'directory': self.workDir+'/{{thisCycleDate}}'+self.memFmt.format(mm),
            'prefix': Forecast.forecastPrefix,
          })

        for k in ['verifyobs', 'verifymodel']:
          postconf[k]['states'] = self.outputs['state']['members'][dtStr]

        postconf['hofx'] = postconf['verifyobs']
        enspost.append(Post(postconf, self.__globalConf))

      # mean forecast
      self.outputs['state']['mean'][dtStr] = StateEnsemble(self.fc.mesh, dt)
      self.outputs['state']['mean'][dtStr].append({
        'directory': self.workDir+'/{{thisCycleDate}}/mean',
        'prefix': Forecast.forecastPrefix,
      })

      for k in ['verifyobs', 'verifymodel']:
        postconf[k]['states'] = self.outputs['state']['mean'][dtStr]

      postconf['hofx'] = postconf['verifyobs']

      meanpost.append(Post(postconf, self.__globalConf))

    if doSingle:
      #######
      # tasks
      #######
      if singleForecastType == 'internal':
        # mean analysis (if needed)
        # TODO: either get meanAnaIC states from MeanAnalysis description or
        #   feed those directories/prefix inputs to bin/MeanAnalysis.csh
        #   via args
        attr = {
          'seconds': {'def': 300},
          'nodes': {'def': 1, 'typ': int},
          'PEPerNode': {'def': 36, 'typ': int},
          'queue': {'def': self.hpc['NonCriticalQueue']},
          'account': {'def': self.hpc['NonCriticalAccount']},
        }
        meanjob = Resource(self._conf, attr, ('job', 'meananalysis'))
        meantask = TaskLookup[self.hpc.system](meanjob)

        self._tasks += ['''
  [[MeanAnalysis]]
    inherit = '''+self.TM.init+''', BATCH
    script = $origin/bin/MeanAnalysis.csh
'''+meantask.job()+meantask.directives()]

        ## from mean analysis (including single-member deterministic)
        self._tasks += ['''
  [[ExtendedMeanFC]]
    inherit = '''+self.TM.execute+''', BATCH
    script = $origin/bin/'''+self.fc.base+'''.csh '''+self.meanAnaArgs]

      elif singleForecastType == 'external':
        ## from external analysis
        self._tasks += ['''
  [[ExtendedFCFromExternalAnalysis]]
    inherit = '''+self.TM.execute+''', BATCH
    script = $origin/bin/'''+self.fc.base+'''.csh '''+self.extAnaArgs]

      ##############
      # dependencies
      ##############
      self.TM.addDependencies([dependency])

      # open graph
      self._dependencies += ['''
    [[['''+self['meanTimes']+''']]]
      graph = """''']

      self._dependencies += self.TM.dependencies()

      for p in meanpost:
        self._tasks += p._tasks
        self._dependencies += p._dependencies

      # close graph
      self._dependencies += ['''
      """''']

    if doEnsemble:
      ## from ensemble of analyses

      #######
      # tasks
      #######

      self._tasks += ['''
  [[ExtendedEnsFC]]
    inherit = '''+self.TM.execute]

      for mm in self.ensVerifyMembers:
        self._tasks += ['''
  [[ExtendedFC'''+str(mm)+''']]
    inherit = ExtendedEnsFC, BATCH
    script = $origin/bin/'''+self.fc.base+'''.csh '''+self.ensAnaArgs[str(mm)]]

      ##############
      # dependencies
      ##############

      self.TM.addDependencies([dependency])

      # open graph
      self._dependencies += ['''
    [[['''+self['ensTimes']+''']]]
      graph = """''']

      self._dependencies += self.TM.dependencies()

      for p in enspost:
        self._tasks += p._tasks
        self._dependencies += p._dependencies

      # close graph
      self._dependencies += ['''
      """''']

    super().export()
