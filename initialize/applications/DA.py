#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

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

    self.__subtasks = []

    # variational
    self.var = Variational(config, hpc, meshes, model, obs, members, workflow, self)
    self.__subtasks += [self.var]

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

    # TODO: mean directories are controlled by external applications (e.g., ExtendedForecast)
    #   and do not need to be defined as inputs/outputs members of DA class
    self.meanBGDir = self.workDir+'/{{thisCycleDate}}/'+self.backgroundPrefix+'/mean'
    if self.NN > 1:
      self.inputs['state']['mean'] = State({
          'directory': self.meanBGDir,
          'prefix': self.backgroundPrefix,
      }, meshes['Outer'])

    # rtpp
    self.rtpp = RTPP(config, hpc, meshes['Ensemble'], members, self,
                       self.inputs['state']['members'], self.outputs['state']['members'])
    self.__subtasks += [self.rtpp]

  def export(self, previousForecast:str, ef:ExtendedForecast):
    self.var.export()
    self.rtpp.export(dependency = self.tf.post, followon = self.tf.finished)

    ########################
    # tasks and dependencies
    ########################
    # open graph
    self._dependencies += ['''
    [[['''+self.workflow['AnalysisTimes']+''']]]
      graph = """''']

    # pre-da observation processing
    self._dependencies += ['''
        '''+self.obs['PrepareObservations']+''' => '''+self.tf.pre]

    # sub-tasks
    for st in self.__subtasks:
      self._tasks += st._tasks
      self._dependencies += st._dependencies

    # depends on previous Forecast
    self.tf.addDependencies([previousForecast])

    # update tasks and dependencies
    self._dependencies = self.tf.updateDependencies(self._dependencies)
    self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

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
        'dependencies': [self.tf.post],
        'followon': [self.tf.clean],
      },
    }

    if len(postconf['tasks']) > 0:
      post = Post(postconf, self.__globalConf)
      self._tasks += post._tasks

      # open graph
      self._dependencies += ['''
      [[['''+self.workflow['AnalysisTimes']+''']]]
        graph = """''']

      self._dependencies += post._dependencies

      self._dependencies = self.tf.updateDependencies(self._dependencies)
      self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

      # close graph
      self._dependencies += ['''
        """''']


    super().export()
