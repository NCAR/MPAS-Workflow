#!/usr/bin/env python3

from collections import OrderedDict

from initialize.applications.ExtendedForecast import ExtendedForecast
from initialize.applications.Members import Members
from initialize.applications.RTPP import RTPP
from initialize.applications.Variational import Variational

from initialize.config.Component import Component
from initialize.config.Config import Config

from initialize.data.Model import Model
from initialize.data.Observations import Observations
from initialize.data.ObsEnsemble import ObsEnsemble
from initialize.data.StateEnsemble import StateEnsemble, State

from initialize.framework.HPC import HPC
from initialize.framework.Workflow import Workflow

from initialize.post.Post import Post

class DA(Component):
  '''
  Framework for all data assimilation (DA) applications.  Can be used to manage interdependent classes
  and cylc tasks, but does not execute any tasks on its own.
  '''
  workDir = 'CyclingDA'
  analysisPrefix = 'an'
  backgroundPrefix = 'bg'

  def __init__(self,
    config:Config,
    hpc:HPC,
    obs:Observations,
    meshes:dict,
    model:Model,
    members:Members,
    workflow:Workflow,
  ):
    super().__init__(config)
    self.__globalConf = config

    self.hpc = hpc
    self.obs = obs
    self.NN = members.n
    self.memFmt = members.memFmt
    self.workflow = workflow

    self.group = 'DAFamily'

    # variational
    self.var = Variational(config, hpc, meshes, model, obs, members, workflow, self)

    # inputs/ouputs
    self.inputs = {}
    self.inputs['state'] = {}
    self.inputs['state']['members'] = StateEnsemble(meshes['Outer'])
    self.outputs = {}
    self.outputs['state'] = {}
    self.outputs['state']['members'] = StateEnsemble(meshes['Outer'])
    self.outputs['obs'] = {}
    self.outputs['obs']['members'] = ObsEnsemble(0)
    for mm in range(1, self.NN+1, 1):
      self.inputs['state']['members'].append({
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.backgroundPrefix+self.memFmt.format(mm),
        'prefix': self.backgroundPrefix,
      })
      self.outputs['state']['members'].append({
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.analysisPrefix+self.memFmt.format(mm),
        'prefix': self.analysisPrefix,
      })
      self.outputs['obs']['members'].append({
        'directory': self.workDir+'/{{thisCycleDate}}/'+Observations.OutDBDir+'/'+self.memFmt.format(mm),
        'observers': self.var['observers']
      })

    self.meanBGDir = self.workDir+'/{{thisCycleDate}}/'+self.backgroundPrefix+'/mean'
    self.meanANDir = self.workDir+'/{{thisCycleDate}}/'+self.analysisPrefix+'/mean'
    if self.NN > 1:
      self.inputs['state']['mean'] = State({
          'directory': self.meanBGDir,
          'prefix': self.backgroundPrefix,
      }, meshes['Outer'])
      self.outputs['state']['mean'] = State({
          'directory': self.meanANDir,
          'prefix': self.analysisPrefix,
      }, meshes['Outer'])

    else:
      self.inputs['state']['mean'] = self.inputs['state']['members'][0]
      self.outputs['state']['mean'] = self.outputs['state']['members'][0]

    # rtpp
    self.rtpp = RTPP(config, hpc, meshes['Ensemble'], members, self,
                       self.inputs['state']['members'], self.outputs['state']['members'])

    self.__subtasks = [self.var, self.rtpp]

  def export(self, forecastFinished:str, ef:ExtendedForecast):
    for st in self.__subtasks:
      st.export()

    ########################
    # tasks and dependencies
    ########################

    phases = [
      self.pre,
      self.init,
      self.execute,
      self.post,
      self.finished,
      self.clean,
    ]

    self._tasks += ['''
  ## data assimilation task markers
  [['''+self.group+''']]''']
    for p in phases:
      self._tasks += ['''
  [['''+p+''']]''']
      if p in [self.init, self.execute]:
        self._tasks += ['''
    inherit = '''+self.group]

    # open graph
    self._dependencies += ['''
    [[['''+self.workflow['AnalysisTimes']+''']]]
      graph = """''']

    self._dependencies += ['''
        # pre => init => execute:succeed-all => post => finished => clean
        # pre-da observation processing
        {{'''+self.obs.workflow+'''}} => '''+self.pre+'''

        # init
        '''+self.pre+''' => '''+self.init+'''

        ## data assimilation
        '''+self.init+''':succeed-all => '''+self.execute+'''

        ## post-da
        # all DA sub-tasks must succeed in order to start post
        '''+self.execute+''':succeed-all => '''+self.post+'''

        # finished after post, clean after finished
        '''+self.post+''' => '''+self.finished+''' => '''+self.clean]

    # sub-tasks
    if self.workflow['CriticalPathType'] in ['Normal', 'Reanalysis']:
      for st in self.__subtasks:
        self._tasks += st._tasks
        self._dependencies += st._dependencies

    if self.workflow['CriticalPathType'] == 'Normal':
      self._dependencies += ['''
        # depends on previous Forecast
        '''+forecastFinished+'''[-PT'''+str(self.workflow['FC2DAOffsetHR'])+'''H] => '''+self.pre]

    # close graph
    self._dependencies += ['''
      """''']

    ######
    # post
    ######
    postconf = {
      'tasks': self.var['post'],
      'valid tasks': ['verifyobs'],
      'verifyobs': {
        'hpc': self.hpc,
        'obs': self.outputs['obs']['members'],
        'sub directory': 'da',
        'dependencies': [self.finished],
        'followon': [self.clean],
      },
    }

    self.__post = Post(postconf, self.__globalConf)
    self._tasks += self.__post._tasks

    # open graph
    self._dependencies += ['''
    [[['''+self.workflow['AnalysisTimes']+''']]]
      graph = """''']

    self._dependencies += self.__post._dependencies

    # close graph
    self._dependencies += ['''
      """''']

    ################################
    # extended forecast verification
    ################################
    if self.workflow['VerifyExtendedMeanFC']:
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

      self._tasks += ['''
  ## mean analysis
  [[MeanAnalysis]]
    inherit = '''+self.group+''', BATCH
    script = $origin/bin/MeanAnalysis.csh
'''+meantask.job()+meantask.directives()]

      self._tasks += ef._tasks

      # open graph
      self._dependencies += ['''
    [[['''+ef['meanTimes']+''']]]
      graph = """''']
      self._dependencies += ['''
        '''+self.finished+''' => MeanAnalysis => ExtendedMeanFC => '''+ef.finished]

      self._dependencies += ef._dependencies

      # close graph
      self._dependencies += ['''
      """''']

# ensemble forecast verfication requires ExtendedForecast tasks and dependencies
# to be defined separately for mean and ensemble
#    if self.workflow['VerifyExtendedEnsFC'] and self.NN > 1:
#      self._tasks += ef._tasks
#
#      # open graph
#      self._dependencies += ['''
#    [[['''+ef['ensTimes']+''']]]
#      graph = """''']
#      self._dependencies += ['''
#        '''+self.finished+''' => ExtendedEnsFC:succeed-all => '''+ef.finished]
#
#      self._dependencies += ef._dependencies
#
#      # close graph
#      self._dependencies += ['''
#      """''']

    super().export()
