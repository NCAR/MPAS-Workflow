#!/usr/bin/env python3

from initialize.config.Configurable import Configurable
from initialize.config.Config import Config

from initialize.data.Model import Model, Mesh
from initialize.data.ObsEnsemble import ObsEnsemble
from initialize.data.StateEnsemble import StateEnsemble

from initialize.framework.HPC import HPC

from initialize.post.VerifyObs import VerifyObs
from initialize.post.VerifyModel import VerifyModel

class Post(Configurable):
  conf = {
    'tasks': {'typ': list, 'required': True},
    'label': {'typ': str, 'required': True},
    'valid tasks': {'typ': str, 'required': True},
    'verifyobs': {'typ': dict},
    'verifymodel': {'typ': dict},
  }

  validTasks = [
    'verifyobs',
    'verifymodel',
  ]

  def __init__(self,
    conf:dict,
    globalConf:Config,
    hpc:HPC,
    mesh:Mesh,
    model:Model,
    states:StateEnsemble = None,
    obs:ObsEnsemble = None,
  ):
    super().__init__(conf)
    self.autoLabel += self['label']

    self.__taskObj = {}

    for t in self['tasks']:
      assert t in self.validTasks, 'Post: invalid task => '+t
      assert t in self['valid tasks'], 'Post: invalid task for parent => '+t

      if t == 'verifyobs':
        self.__taskObj[t] = VerifyObs(globalConf,
          self[t], hpc, mesh, model, states = states, obs = obs)
 
      if t == 'verifymodel':
        self.__taskObj[t] = VerifyModel(globalConf,
          self[t], hpc, mesh, states)

  def export(self, components):
    self.__tasks = []
    self.__dependencies = []
    for t in self.__taskObj.values():
      t.export(components)
      self.__tasks += t._tasks
      self.__dependencies += t._dependencies

    self.__exportTasks()
    self.__exportDependencies()

    return

  ## export methods
  @staticmethod
  def __appendToTextFile(filename, Str):
    #if len(Str) == 0: return
    #self._msg('Creating '+filename)
    with open(filename, 'a') as f:
      f.writelines(Str)
      f.close()
    return

  # cylc dependencies
  def __exportDependencies(self):
    self.__appendToTextFile('include/dependencies/auto/'+self.autoLabel+'.rc', self.__dependencies)
    return

  # cylc tasks
  def __exportTasks(self):
    self.__appendToTextFile('include/tasks/auto/'+self.autoLabel+'.rc', self.__tasks)
    return
