#!/usr/bin/env python3

from initialize.config.Component import Component
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

    posts = []
    self._tasks = []
    self._dependencies = []

    for P in self.posts:
      assert issubclass(P, Component), 'Post: P must be a Component, not '+str(type(P))
      plow = P.__name__.lower()
      if plow in self['tasks']:
        assert plow in conf['valid tasks'], 'Post: invalid task for parent => '+plow
        posts.append(P(globalConf, conf[plow]))

    for p in posts:
      p.export()
      self._tasks += p._tasks
      self._dependencies += p._dependencies
