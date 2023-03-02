#!/usr/bin/env python3

#from typing import Iterable, Callable, Union, Tuple, Type, Mapping
#from collections.abc import Iterable

from initialize.config.Config import Config

class Resource(Config):
  '''
  general purpose nested Config sub-class

  useful for extracting resource-dependent or mesh-dependent subconfigurations
  '''
  def __init__(self, config:Config, keys:dict, resource:tuple):
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
    '''
    self._table = {}
    self._defaults = {}

    for key, att in keys.items():
      default = att.get('def', None)
      required = att.get('req', True)
      t = att.get('t', None)

      if default is not None:
        self._table[key] = self.extractNodeOrDefault(config, resource, key, default, t)
      elif required:
        self._table[key] = self.extractNodeOrDie(config, resource, key, t)
      else:
        self._table[key] = self.extractNode(config, resource, key, t)

  @staticmethod
  def extractNode(config, resource:tuple, key:str, t=None):
    value = None
    for i in range(len(resource), -1, -1):
      l = list(resource[:i+1])
      if None in l: continue
      if value is None:
        value = config.get('.'.join(l+[key]), t)

      if value is None:
        value = config.get('.'.join(l+['common', key]), t)

    if value is None:
      value = config.get('.'.join([resource[0], 'defaults', key]), t)

    return value

  def extractNodeOrDie(self, config, resource, key, t=None):
    v = self.extractNode(config, resource, key, t)
    assert v is not None, (str(resource)+'.'+key+' targets invalid or nonexistent node')
    return v

  def extractNodeOrDefault(self, config, resource, key, default, t=None):
    v = self.extractNode(config, resource, key, t)
    if v is None:
      v = default
    return v

  def _set(self, key, value):
    'allow manual override'
    self._table[key] = value
