#!/usr/bin/env python3

from initialize.components.Model import Mesh
from initialize.data.DataList import DataList
from initialize.Configurable import Configurable

class StateEnsemble(DataList):
  def __init__(self, mesh:Mesh):

    super().__init__(self.check_method)

    self.__mesh = mesh

  def check_method(self, val):
    if isinstance(val, dict):
      return State(val, self.__mesh)
    elif isinstance(val, State):
      return val
    else:
      raise TypeError

  def mesh(self):
    return self.__mesh

class State(Configurable):
  conf = {
    'directory': {'typ': str, 'required': True},
    'prefix': {'typ': str, 'required': True},
  }
  def __init__(self, conf:dict, mesh:Mesh):
    super().__init__(conf)
    self.__mesh = mesh

  def location(self):
    return self.directory()+'/'+self.prefix()

  def directory(self):
    return self._conf['directory']

  def prefix(self):
    return self._conf['prefix']

  def mesh(self):
    return self.__mesh
