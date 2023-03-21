#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.config.Configurable import Configurable

from initialize.data.Model import Mesh
from initialize.data.DataList import DataList

class StateEnsemble(DataList):
  def __init__(self, mesh:Mesh, duration=0):

    super().__init__(self.check_method)

    self.__mesh = mesh
    self.__duration = duration

  def check_method(self, val):
    if isinstance(val, dict):
      return State(val, self.__mesh)
    elif isinstance(val, State):
      return val
    else:
      raise TypeError

  def mesh(self):
    return self.__mesh

  def duration(self):
    return self.__duration

class State(Configurable):
  conf = {
    'directory': {'typ': str, 'req': True},
    'prefix': {'typ': str, 'req': True},
  }
  def __init__(self, conf:dict, mesh:Mesh):
    super().__init__(conf)
    self.__mesh = mesh

  def location(self):
    return self.directory()+'/'+self.prefix()

  def directory(self):
    return self['directory']

  def prefix(self):
    return self['prefix']

  def mesh(self):
    return self.__mesh
