#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.applications.HofX import HofX

from initialize.config.Component import Component
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
    # tasks selected by caller
    'tasks': {'typ': list, 'req': True},
    # valid tasks according to caller
    'valid tasks': {'typ': str, 'req': True},
  }

  # can only construct instances of classes in posts[:]
  posts = [
    HofX,
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
