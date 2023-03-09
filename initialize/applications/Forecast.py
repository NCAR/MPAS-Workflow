#!/usr/bin/env python3

from copy import deepcopy

from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.Model import Model, Mesh
from initialize.data.Observations import Observations
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
    obs:Observations,
    workflow:Workflow,
    ea:ExternalAnalyses,
    coldIC:StateEnsemble,
    warmIC:StateEnsemble,
  ):
    super().__init__(config)
    self.__globalConf = config
    self.mesh = mesh
    self.model = model
    self.workflow = workflow
    self.ea = ea
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

    #######
    # tasks
    #######
    # only run 1st cycle, derived from group
    self._tasks += ['''
  [[Cold'''+self.base+''']]
    inherit = '''+self.TM.group+'''
'''+task.job()+task.directives()]

    # derived from every-cycle execute
    self._tasks += ['''
  [['''+self.TM.execute+''']]
'''+task.job()+task.directives()+'''

  ## post mean background
  [[MeanBackground]]
    inherit = '''+self.TM.group+''', BATCH
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
    inherit = '''+self.TM.execute+''', BATCH
    script = $origin/bin/'''+self.base+'''.csh '''+WarmArgs]

    self.previousForecast = self.TM.finished+'[-PT'+str(self.workflow['FC2DAOffsetHR'])+'H]'

    # TODO: move Post initialization out of Forecast class so that PrepareObservations
    #  can be appropriately referenced without adding a dependence of the Forecast class
    #  on the Observations class
    self.postconf = {
      'tasks': self['post'],
      'valid tasks': ['hofx', 'verifyobs', 'verifymodel'],
      'verifyobs': {
        'hpc': hpc,
        'mesh': mesh,
        'model': model,
        'sub directory': 'bg',
        'dependencies': [self.previousForecast, obs['PrepareObservations']],
      },
      'verifymodel': {
        'hpc': hpc,
        'mesh': mesh,
        'sub directory': 'bg',
        'dependencies': [self.previousForecast, ea['PrepareExternalAnalysisOuter']],
      },
    }

  def export(self, daFinished:str, daClean:str, daMeanDir:str):
    #########
    # outputs
    #########
    self.outputs = {}
    self.outputs['state'] = {}

    self.outputs['state']['members'] = StateEnsemble(self.mesh)
    for mm in range(1, self.NN+1, 1):
      self.outputs['state']['members'].append({
        'directory': self.workDir+'/{{prevCycleDate}}'+self.memFmt.format(mm),
        'prefix': self.forecastPrefix,
      })

    self.outputs['state']['mean'] = StateEnsemble(self.mesh)
    # TODO: create MeanBackground class that defines daMeanDir
    #   and passes it to MeanBackground.csh script as an arg
    self.outputs['state']['mean'].append({
      'directory': daMeanDir,
      'prefix': self.forecastPrefix,
    })

    #######
    # tasks
    #######

    self._tasks += self.TM.tasks()

    ##############
    # dependencies
    ##############

    # open graph
    self._dependencies += ['''
    [[['''+self.workflow['ForecastTimes']+''']]]
      graph = """''']

    # {{ForecastTimes}} dependencies only, not the R1 cycle
    self._dependencies += ['''
        # ensure there is a valid sea-surface update file before forecast
        '''+self.ea['PrepareSeaSurfaceUpdate']+''' => '''+self.TM.pre]

    if self.workflow['CriticalPathType'] == 'Normal':
      # depends on previous DA
      self.TM.addDependencies([daFinished+'[-PT'+str(self.workflow['DA2FCOffsetHR'])+'H]'])
    else:
      self._dependencies += ['''
        '''+self.TM.finished]

    self._dependencies += self.TM.dependencies()

    # close graph
    self._dependencies += ['''
      """''']

    ######
    # post
    ######

    __post = []

    # mean case when self.NN > 1
    if self.NN > 1:
      self._dependencies += ['''
    [[['''+self.workflow['AnalysisTimes']+''']]]
      graph = """
        '''+self.previousForecast+''' => MeanBackground
      """''']

      # store original conf values
      pp = deepcopy(self.postconf)

      # re-purpose for mean bg tasks
      for k in ['verifyobs', 'verifymodel']:
        self.postconf[k]['dependencies'] += ['MeanBackground']
        self.postconf[k]['member multiplier'] = self.NN
        self.postconf[k]['states'] = self.outputs['state']['mean']

      # mean-state model verification; also diagnoses posterior ensemble spread
      self.postconf['verifymodel']['dependencies'] += [daFinished]
      self.postconf['verifymodel']['followon'] = [daClean]

      self.postconf['hofx'] = self.postconf['verifyobs']

      __post.append(Post(self.postconf, self.__globalConf))

      # restore original conf values
      self.postconf = deepcopy(pp)

      # only need verifyobs from individual ensemble members; used to calculate ensemble spread
      if 'verifyobs' in self.postconf['tasks']:
        self.postconf['tasks'] = ['verifyobs']
      else:
        self.postconf['tasks'] = []

    # close dependency graph

    # member case (mean case when NN == 1)
    for k in ['verifyobs', 'verifymodel']:
      self.postconf[k]['states'] = self.outputs['state']['members']

    self.postconf['hofx'] = self.postconf['verifyobs']

    __post.append(Post(self.postconf, self.__globalConf))

    ########
    # export
    ########

    # open graph
    self._dependencies += ['''
    [[['''+self.workflow['AnalysisTimes']+''']]]
      graph = """''']

    for p in __post:
      self._tasks += p._tasks
      self._dependencies += p._dependencies

    # close graph
    self._dependencies += ['''
      """''']

    super().export()
