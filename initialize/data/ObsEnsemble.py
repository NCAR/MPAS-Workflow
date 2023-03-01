#!/usr/bin/env python3

from initialize.data.DataList import DataList
from initialize.Configurable import Configurable

class ObsEnsemble(DataList):
  def __init__(self):
    super().__init__(self.check_method)

  @staticmethod
  def check_method(val):
    if isinstance(val, dict):
      return ObsDB(val)
    elif isinstance(val, State):
      return val
    else:
      raise TypeError

class ObsDB(Configurable):
  conf = {
    'directory': {'typ': str, 'required': True},
    'observers': {'typ': list, 'required': True},
  }
  def __init__(self, conf:dict):
    super().__init__(conf)

  def directory(self):
    return self._conf['directory']

  def observers(self):
    return self._conf['observers']
