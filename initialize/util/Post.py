#!/usr/bin/env python3

from initialize.components.HPC import HPC
from initialize.components.Mesh import Mesh
from initialize.components.Model import Model
from initialize.components.VerifyObs import VerifyObs
from initialize.components.VerifyModel import VerifyModel

from initialize.Configurable import Configurable
from initialize.Config import Config

class Post(Configurable):
  conf = {
    'tasks': {'typ': list, 'required': True},
    'label': {'typ': str, 'required': True},
  }

  validTasks = [
    'verifyobs',
    'verifymodel',
  ]

  def __init__(self,
    conf:dict,
    globalConf:Config,
    parentValidTasks:list,
    hpc:HPC,
    mesh:Mesh,
    model:Model,
    memberMultiplier:int = 1,
    states:StateEnsemble = None,
    obs:ObsEnsemble = None,
  ):
    super().__init__(conf)
    self.autoLabel += self['label']

    self.__taskObj = {}

    for t in self['tasks']:
      assert t in self.validTasks, 'Post: invalid task => '+t
      assert t in parentValidTasks, 'Post: invalid task for parent => '+t

    t = 'verifyobs'
    if t in self['tasks']:
      if obs is None:
        self.__taskObj[t] = VerifyObs(globalConf,
          hpc,
          mesh,
          model,
          self['label'],
          self['dependencies'][t],
          self.get('followon', {}).get(t, []),
          memberMultiplier,
          states = states)
      else:
        self.__taskObj[t] = VerifyObs(globalConf,
          hpc,
          mesh,
          model,
          self['label'],
          self['dependencies'][t],
          self.get('followon', {}).get(t, []),
          memberMultiplier,
          obs = obs)
 
    t = 'verifymodel'
    if t in self['tasks']:
      assert states is not None, 'Post: states must be defined for '+t
      self.__taskObj[t] = VerifyModel(globalConf,
        hpc,
        mesh,
        self['label'],
        self['dependencies'][t],
        self.get('followon', {}).get(t, []),
        memberMultiplier,
        states)

  def export(self, components):
    for t in self.__taskObj.values():
      self._tasks += t._tasks
      self._dependencies += t._dependencies

    self.__exportTasks()
    self.__exportDependencies()

    return

  ## export methods
  @staticmethod
  def __toTextFile(filename, Str):
    #if len(Str) == 0: return
    #self._msg('Creating '+filename)
    with open(filename, 'w') as f:
      f.writelines(Str)
      f.close()
    return

  # cylc dependencies
  def __exportDependencies(self):
    self.__toTextFile('include/dependencies/auto/'+self.autoLabel+'.rc', self._dependencies)
    return

  # cylc tasks
  def __exportTasks(self):
    self.__toTextFile('include/tasks/auto/'+self.autoLabel+'.rc', self._tasks)
    return
