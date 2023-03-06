#!/usr/bin/env python3

from initialize.config.Configurable import Configurable
from initialize.config.Config import Config

from initialize.data.Model import Model, Mesh
from initialize.data.ObsEnsemble import ObsEnsemble
from initialize.data.StateEnsemble import StateEnsemble

from initialize.framework.HPC import HPC

from initialize.post.VerifyObs import VerifyObs
from initialize.post.VerifyModel import VerifyModel

#taskLookup = {
#  'verifyobs': VerifyObs,
#  'verifymodel': VerifyModel,
#}

class Post(Configurable):
  conf = {
    'tasks': {'typ': list, 'req': True},
    'label': {'typ': str, 'req': True},
    'valid tasks': {'typ': str, 'req': True},
  }

  posts = [
    VerifyObs,
    VerifyModel,
  ]

  def __init__(self,
    conf:dict,
    globalConf:Config,
  ):
    super().__init__(conf)
    self.autoLabel += self['label']

    self.__posts = {}

    for P in self.posts:
      plow = P.__name__.lower()
      if plow in self['tasks']:
        assert plow in conf['valid tasks'], 'Post: invalid task for parent => '+plow
        self.__posts[plow] = P(globalConf, conf[plow])
 
  def export(self, components):
    self.__tasks = []
    self.__dependencies = []
    for p in self.__posts.values():
      p.export(components)
      self.__tasks += p._tasks
      self.__dependencies += p._dependencies

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
