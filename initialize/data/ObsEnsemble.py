#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.config.Configurable import Configurable
from initialize.data.DataList import DataList

class ObsEnsemble(DataList):
  def __init__(self, duration:int=0):
    super().__init__(self.check_method)
    self.__duration = duration

  @staticmethod
  def check_method(val):
    if isinstance(val, dict):
      return ObsDB(val)
    elif isinstance(val, State):
      return val
    else:
      raise TypeError

  def duration(self):
    return self.__duration

class ObsDB(Configurable):
  conf = {
    'directory': {'typ': str, 'req': True},
    'observers': {'typ': list, 'req': True},
  }
  def __init__(self, conf:dict):
    super().__init__(conf)

  def directory(self):
    return self['directory']

  def observers(self):
    return self['observers']
