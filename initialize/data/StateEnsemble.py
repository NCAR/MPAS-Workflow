#!/usr/bin/env python3

from initialize.components.Model import Mesh
from initialize.data.DataList import DataList

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

class State:
  def __init__(self, conf:dict, mesh:Mesh):
    assert set(conf.keys()) == set(['directory', 'prefix']), 'State: invalid conf element'+str(conf)

    self.__directory = str(conf['directory'])
    self.__prefix = str(conf['prefix'])
    self.__mesh = mesh

#  def location(self):
#    return self.__directory+'/'+self.__prefix

  def directory(self):
    return self.__directory

  def prefix(self):
    return self.__prefix

  def mesh(self):
    return self.__mesh
