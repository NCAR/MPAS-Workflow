#!/usr/bin/env python3

#from typing import Iterable, Callable, Union, Tuple, Type, Mapping
#from collections.abc import Iterable

from initialize.Config import Config

class Resource(Config):
  '''
  general purpose nested Config sub-class

  useful for extracting resource-dependent or mesh-dependent subconfigurations
  '''
  def __init__(self, config:Config, keys:dict, r1:str = None, r2:str = None):
    '''
    keys: {key1[str]: {
              'def': default value, # optional
              'req': required, # bool, optional, True when missing
              't': type}, # e.g., int, float, str, list, optional, None when missing
            key2[str]: {
              'def': default value, # optional
              'req': required, # bool, optional, True when missing
              't': type}, # e.g., int, float, str, list, optional, None when missing
           }
    r1 (optional): first yaml node level under which the Resource is located
    r2 (optional): second yaml node level ...
    '''
    self._table = {}
    self._defaults = {}

    if r1 is None:
      r1_ = ''
    else:
      r1_ = r1

    if r2 is None:
      r2_ = ''
    else:
      r2_ = r2

    for key, att in keys.items():
      default = att.get('def', None)
      required = att.get('req', True)
      t = att.get('t', None)

      if default is not None:
        self._table[key] = self.extractNodeOrDefault(config, r1_, r2_, key, default, t)
      elif required:
        self._table[key] = self.extractNodeOrDie(config, r1_, r2_, key, t)
      else:
        self._table[key] = self.extractNode(config, r1_, r2_, key, t)

  @staticmethod
  def extractNode(config, r1, r2, key, t=None):
      value = config.get('.'.join([r1, r2, key]), t)

      if value is None:
        value = config.get('.'.join([r1, key]), t)

      if value is None:
        value = config.get('.'.join([r1, 'common', key]), t)

      if value is None:
        value = config.get('.'.join([r1, 'defaults', key]), t)

      if value is None:
        value = config.get('.'.join(['defaults', key]), t)

      return value

  def extractNodeOrDie(self, config, r1, r2, key, t=None):
    v = self.extractNode(config, r1, r2, key, t)
    assert v is not None, (r1+', '+r2+', '+key+' targets invalid or nonexistent node')
    return v

  def extractNodeOrDefault(self, config, r1, r2, key, default, t=None):
    v = self.extractNode(config, r1, r2, key, t)
    if v is None:
      v = default
    return v

  def _set(self, key, value):
    'allow manual override'
    self._table[key] = value
