#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

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
    ic:StateEnsemble,
    icType:str,
  ):
    self.__globalConf = config
    super().__init__(config)
    self.NN = members.n
    self.memFmt = members.memFmt
    self.hpc = hpc
    self.fc = fc
    self.ea = ea
    self.obs = obs

    assert fc.mesh == ic.mesh(), 'ic must be on same mesh as extended forecast'
    assert icType in ['internal','external'], (
     'ExtendedForecast.__init__: incorrect icType => '+icType)

    ###################
    # derived variables
    ###################

    lengthHR = self['lengthHR']
    outIntervalHR = self['outIntervalHR']
    extLengths = range(0, lengthHR+outIntervalHR, outIntervalHR)
    self._set('extLengths', extLengths)
    self.ensVerifyMembers = range(1, self.NN+1, 1)

    self.doMean = (self['meanTimes'] is not None)

    #########################################
    # group base task and args to executables
    #########################################
    # job settings for self.base
    job = fc.job
    job._set('seconds', job['baseSeconds'] + job['secondsPerForecastHR'] * lengthHR)
    job._set('queue', hpc['NonCriticalQueue'])
    job._set('account', hpc['NonCriticalAccount'])
    fctask = TaskLookup[hpc.system](job)

    self._tasks += ['''
  [['''+self.base+''']]
'''+fctask.job()+fctask.directives()]

    if icType == 'external':
      self.fromExternalAnalysis(ic)
    elif icType == 'internal':
      self.fromInternalAnalysis(ic)

  def fromExternalAnalysis(self, states:StateEnsemble):
    # only singl-state forecasts are supported when initializing from external analyses,
    # consistent with ExternalAnalyses functionality
    assert self.NN == 1, (
      'fromExternalAnalysis.__init__: only compatible with single-member forecasts')

    # mean analysis
    args = [
      1,
      self['lengthHR'],
      self['outIntervalHR'],
      False,
      self.fc.mesh.name,
      False,
      False,
      False,
      self.workDir+'/{{thisCycleDate}}/mean',
      states[0].directory(),
      states[0].prefix(),
    ]
    self.meanAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

    # ensemble of analyses
    self.ensAnaArgs = {}
    for mm in self.ensVerifyMembers:
      self.ensAnaArgs[str(mm)] = self.meanAnaArgs

  def fromInternalAnalysis(self, states:StateEnsemble):
    # mean analysis
    attr = {
      'seconds': {'def': 300},
      'nodes': {'def': 1, 'typ': int},
      'PEPerNode': {'def': 36, 'typ': int},
      'queue': {'def': self.hpc['NonCriticalQueue']},
      'account': {'def': self.hpc['NonCriticalAccount']},
    }
    meanjob = Resource(self._conf, attr, ('job', 'meananalysis'))
    meantask = TaskLookup[self.hpc.system](meanjob)

    if self.doMean:
      self._tasks += ['''
  [[MeanAnalysis]]
    inherit = '''+self.tf.init+''', BATCH
    script = $origin/bin/MeanAnalysis.csh
'''+meantask.job()+meantask.directives()]

    # outputs from MeanAnalysis
    # TODO: create MeanAnalysis class that defines meanANDir
    #   and passes it to MeanAnalysis.csh as an arg
    #   Can MeanAnalysis class depend on DA?
    #meanANDir = DA.workDir+'/{{thisCycleDate}}/'+DA.analysisPrefix+'/mean'
    meanANDir = 'CyclingDA/{{thisCycleDate}}/an/mean'

    meanInternalAnaIC = State({
        'directory': meanANDir,
        #'prefix': DA.analysisPrefix,
        'prefix': 'an',
    }, states.mesh())
    args = [
      1,
      self['lengthHR'],
      self['outIntervalHR'],
      False,
      self.fc.mesh.name,
      True,
      False,
      True,
      self.workDir+'/{{thisCycleDate}}/mean',
      meanInternalAnaIC.directory(),
      meanInternalAnaIC.prefix(),
    ]
    self.meanAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

    # ensemble of analyses
    self.ensAnaArgs = {}
    for mm in self.ensVerifyMembers:
      args = [
        mm,
        self['lengthHR'],
        self['outIntervalHR'],
        False,
        self.fc.mesh.name,
        True,
        False,
        True,
        self.workDir+'/{{thisCycleDate}}'+self.memFmt.format(mm),
        states[mm-1].directory(),
        states[mm-1].prefix(),
      ]
      self.ensAnaArgs[str(mm)] = ' '.join(['"'+str(a)+'"' for a in args])

  def export(self,
    dependency:str,
    activateEnsemble:bool=False,
  ):
    '''
    dependency: single task on which extended forecast tasks depend
    activateEnsemble: whether to activate ensemble extended forecasts (False by default)
    '''

    doEnsemble = (self['ensTimes'] is not None and self.NN > 1 and activateEnsemble)

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

    meanposts = []
    ensposts = []

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

      postconf['verifyobs']['dependencies'] = [self.tf.finished, prepObs]
      postconf['verifymodel']['dependencies'] = [self.tf.finished, prepEA]

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

        if len(postconf['tasks']) > 0:
          ensposts.append(Post(postconf, self.__globalConf))

      # mean forecast
      if self.doMean:
        self.outputs['state']['mean'][dtStr] = StateEnsemble(self.fc.mesh, dt)
        self.outputs['state']['mean'][dtStr].append({
          'directory': self.workDir+'/{{thisCycleDate}}/mean',
          'prefix': Forecast.forecastPrefix,
        })

        for k in ['verifyobs', 'verifymodel']:
          postconf[k]['states'] = self.outputs['state']['mean'][dtStr]

        postconf['hofx'] = postconf['verifyobs']

        if len(postconf['tasks']) > 0:
          meanposts.append(Post(postconf, self.__globalConf))

    if self.doMean:
      #######
      # tasks
      #######
      self._tasks += ['''
  [[ExtendedMeanFC]]
    inherit = '''+self.tf.execute+''', '''+self.base+''', BATCH
    script = $origin/bin/'''+self.fc.base+'''.csh '''+self.meanAnaArgs]

      ##############
      # dependencies
      ##############
      self.tf.addDependencies([dependency])

      # open graph
      self._dependencies += ['''
    '''+self['meanTimes']+''' = """''']

      for p in meanposts:
        self._tasks += p._tasks
        self._dependencies += p._dependencies

      self._dependencies = self.tf.updateDependencies(self._dependencies)

      # close graph
      self._dependencies += ['''
      """''']

    if doEnsemble:
      #######
      # tasks
      #######

      self._tasks += ['''
  [[ExtendedEnsFC]]
    inherit = '''+self.tf.execute+''', '''+self.base]

      for mm, args in self.ensAnaArgs.items():
        self._tasks += ['''
  [[ExtendedFC'''+mm+''']]
    inherit = ExtendedEnsFC, BATCH
    script = $origin/bin/'''+self.fc.base+'''.csh '''+args]

      ##############
      # dependencies
      ##############

      self.tf.addDependencies([dependency])

      # open graph
      self._dependencies += ['''
    '''+self['ensTimes']+''' = """''']

      for p in ensposts:
        self._tasks += p._tasks
        self._dependencies += p._dependencies

      self._dependencies = self.tf.updateDependencies(self._dependencies)

      # close graph
      self._dependencies += ['''
      """''']

    self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

    super().export()
