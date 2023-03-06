#!/usr/bin/env python3

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
    return self._conf['directory']

  def observers(self):
    return self._conf['observers']
