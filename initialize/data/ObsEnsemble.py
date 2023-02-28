#!/usr/bin/env python3

from initialize.data.DataList import DataList

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


class ObsDB:
  def __init__(self, conf:dict):
    assert set(conf.keys()) == set(['directory', 'observers']), 'State: invalid conf element'+str(conf)
    self.__directory = str(conf['directory'])
    self.__observers = list(conf['observers'])

  def directory(self):
    return self.__directory

  def observers(self):
    return self.__observers
