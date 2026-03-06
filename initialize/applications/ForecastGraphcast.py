#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

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
  defaults = 'scenarios/defaults/forecastgraphcast.yaml'
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

    ## 4D
    # whether to use 4D forecast outputs
    'FourD': [False, bool],

    ## post
    # list of tasks for Post
    # e.g.: ['verifyobs', 'verifymodel']
    'post': [['verifymodel'], list],

    # directory containing GFS WPS file
    'dirWPSFilesGFS': ['/glade/derecho/scratch/stoedtli/gfs_wps_files', str],
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
    warmIC:StateEnsemble,
  ):
    super().__init__(config)
    self.__globalConf = config
    self.hpc = hpc
    self.mesh = mesh
    self.model = model
    self.workflow = workflow
    self.ea = ea
    self.NN = members.n
    self.memFmt = members.memFmt

    assert mesh == warmIC.mesh(), 'warmIC must be on same mesh as forecast'

    ###################
    # derived variables
    ###################

    IAU = self['IAU']
    FourD = self['FourD']

    window = workflow['CyclingWindowHR']
    subwindow = workflow['subwindow']
    if IAU:
      outIntervalHR = window // 2
      lengthHR = 3 * outIntervalHR
    elif FourD:
      outIntervalHR = subwindow
      lengthHR = window + window // 2
    else:
      outIntervalHR = window
      lengthHR = window

    self._set('outIntervalHR', outIntervalHR)
    self._set('lengthHR', lengthHR)

    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    # job settings
    updateSea = self['updateSea']

    # Notes:
    # - removed job_priority flag for now (not sure if it is supported on Casper)
    attr = {
      'retry': {'typ': str},
      'baseSeconds': {'typ': int},
      'secondsPerForecastHR': {'typ': int},
      'nodes': {'def': 1, 'typ': int},
      'PEPerNode': {'def': 1, 'typ': int},
      'GPUPerNode': {'def': 1, 'typ': int},
      'GPUType': {'def': 'a100_80gb', 'typ': str},
      'memory': {'def': '20GB', 'typ': str},
      'queue': {'def': hpc['SingleProcQueue']},  # submit to Casper
      # 'account': {'def': hpc['CriticalAccount']},
      'account': {'def': hpc['GPUAccount']},
      'email': {'def': True, 'typ': bool},
    }
    # store job for ExtendedForecast to re-use
    resourceForecast = mesh.name + '.graphcast'
    self.job = Resource(self._conf, attr, ('job', resourceForecast))
    self.job._set('seconds', self.job['baseSeconds'] + self.job['secondsPerForecastHR'] * lengthHR)
    task = TaskLookup[hpc.system](self.job)

    #######
    # tasks
    #######
    # warm-start, run all cycles
    # base task derived from every-cycle execute
    self._tasks += ['''
  [['''+self.base+''']]
    inherit = '''+self.tf.execute+'''
'''+task.job()+task.directives()]
    
    # only add these tasks if the forecast is to be executed
    if self['execute']:
      # Graphcast forecast
      self._tasks += [('\n'
                      '  [[ForecastGC]]'
                      '\n'
                      f'    inherit = {self.tf.base}, BATCH'
                      '\n'
                      f'    script = $origin/bin/ForecastGraphcast.csh'
                      '\n'
      )]

      # Interpolation to MPAS mesh
      keyListInterpolation = {
        # Notes:
        # - the interpolation application is currently small enough to run on develop
        'retry': {'typ': str},
        'baseSeconds': {'typ': int},
        'secondsPerMember': {'typ': int},
        'nodes': {'def': 1, 'typ': int},
        'PEPerNode': {'def': 1, 'typ': int},
        'memory': {'def': '20GB', 'typ': str},
        'queue': {'def': hpc['SharedQueue']},
        'account': {'def': hpc['CriticalAccount']},
        'email': {'def': True, 'typ': bool},
      }
      resourceInterpolation = mesh.name + '.interpolation'
      interpolationJob = Resource(self._conf, keyListInterpolation, ('job', resourceInterpolation))
      interpolationJob._set('seconds', interpolationJob['baseSeconds'] + interpolationJob['secondsPerMember'] * self.NN)
      interpolationTask = TaskLookup[hpc.system](interpolationJob)

      self._tasks += [('\n'
                      '  [[InterpolateGCToMPAS]]'
                      '\n'
                      f'    inherit = {self.tf.execute}, BATCH'
                      '\n'
                      f'    script = $origin/bin/InterpolateGraphcast.csh'
                      '\n'
                      f'{interpolationTask.job() + interpolationTask.directives()}'
                      '\n')]

  #   for mm in range(1, self.NN+1, 1):
  #     # fcArgs explanation
  #     # DACycling (True), IC ~is~ a DA analysis for which re-coupling is required
  #     # DeleteZerothForecast (False), not used anywhere else in the workflow
  #     args = [
  #       mm,
  #       lengthHR,
  #       outIntervalHR,
  #       IAU,
  #       mesh.name,
  #       True,
  #       False,
  #       updateSea,
  #       self.workDir+'/{{thisCycleDate}}'+self.memFmt.format(mm),
  #       warmIC[mm-1].directory(),
  #       warmIC[mm-1].prefix(),
  #     ]
  #     fcArgs = ' '.join(['"'+str(a)+'"' for a in args])

  #     self._tasks += ['''
  # [['''+self.base+str(mm)+''']]
  #   inherit = '''+self.base+''', BATCH
  #   script = $origin/bin/'''+self.base+'''.csh '''+fcArgs]

    self.previousForecast = self.tf.finished+'[-PT'+str(self.workflow['FC2DAOffsetHR'])+'H]'

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

  def export(self, daFinished:str, daMeanDir:str):
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

    ##############
    # dependencies
    ##############

    # open graph
    self._dependencies += ['''
    '''+self.workflow['ForecastTimes']+''' = """''']

    # {{ForecastTimes}} dependencies only, not the R1 cycle
    self._dependencies += ['''
        # ensure there is a valid sea-surface update file before forecast
        '''+self.ea['PrepareSeaSurfaceUpdate']+''' => '''+self.tf.pre]
    
    # Use graphcast to generate forecast and interpolate to native MPAS mesh.
    # Add dependency only if we want to run a forecast.
    if self['execute']:
      self._dependencies += [('\n'
                              f'        ForecastGC => InterpolateGCToMPAS => {self.tf.post}')]

    # depends on previous DA
    previousDA = daFinished+'[-PT'+str(self.workflow['DA2FCOffsetHR'])+'H]'
    self.tf.addDependencies([previousDA])

    self._dependencies = self.tf.updateDependencies(self._dependencies)
    self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

    # close graph
    self._dependencies += ['''
      """''']

    ######
    # post
    ######

    posts = []
    if self.NN > 1:
      # MeanBackground
      # TODO: ABEI depends on MeanBackground too, need to move outside of Forecast
      attr = {
        'seconds': {'def': 300},
        'nodes': {'def': 1, 'typ': int},
        'PEPerNode': {'def': 128, 'typ': int},
        'queue': {'def': self.hpc['NonCriticalQueue']},
        'account': {'def': self.hpc['NonCriticalAccount']},
        'job_priority': {'def': self.hpc['NonCriticalPriority']},
      }
      meanjob = Resource(self._conf, attr, ('job', 'meanbackground'))
      meantask = TaskLookup[self.hpc.system](meanjob)

      self._tasks += ['''
    [[MeanBackground]]
      inherit = BATCH
      script = $origin/bin/MeanBackground.csh
'''+meantask.job()+meantask.directives()]

      self._dependencies += ['''
      '''+self.workflow['AnalysisTimes']+''' = """
          '''+self.previousForecast+''' => MeanBackground
        """''']

    if len(self.postconf['tasks']) > 0:
      ## mean case (only if NN > 1)
      if self.NN > 1:
        # store original conf values
        pp = deepcopy(self.postconf)

        # re-purpose for mean bg tasks
        for k in ['verifyobs', 'verifymodel']:
          self.postconf[k]['dependencies'] += ['MeanBackground']
          self.postconf[k]['member multiplier'] = self.NN
          self.postconf[k]['states'] = self.outputs['state']['mean']

        # mean-state model verification
        # also diagnoses posterior/inflated ensemble spread (after RTPP)
        self.postconf['verifymodel']['dependencies'] += [daFinished]

        self.postconf['hofx'] = self.postconf['verifyobs']

        posts.append(Post(self.postconf, self.__globalConf))

        # restore original conf values
        self.postconf = deepcopy(pp)

        # only need verifyobs from individual ensemble members; used to calculate ensemble spread
        if 'verifyobs' in self.postconf['tasks']:
          self.postconf['tasks'] = ['verifyobs']
        else:
          self.postconf['tasks'] = []

      ## members case (mean case when NN == 1)
      for k in ['verifyobs', 'verifymodel']:
        self.postconf[k]['states'] = self.outputs['state']['members']

      self.postconf['hofx'] = self.postconf['verifyobs']

      posts.append(Post(self.postconf, self.__globalConf))

      ## export

      # open graph
      self._dependencies += ['''
      '''+self.workflow['AnalysisTimes']+''' = """''']

      for p in posts:
        self._tasks += p._tasks
        self._dependencies += p._dependencies

      self._dependencies = self.tf.updateDependencies(self._dependencies)
      self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

      # close graph
      self._dependencies += ['''
        """''']

    super().export()
