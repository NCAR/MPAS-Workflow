#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

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
              'typ': type}, # e.g., int, float, str, list, optional, None when missing
            key2[str]: {
              'def': default value, # optional
              'req': required, # bool, optional, True when missing
              'typ': type}, # e.g., int, float, str, list, optional, None when missing
           }
    '''
    self._table = {}
    self._defaults = {}

    for key, att in keys.items():
      default = att.get('def', None)
      required = att.get('req', True)
      typ = att.get('typ', None)

      if default is not None:
        self._table[key] = self.extractNodeOrDefault(config, resource, key, default, typ)
      elif required:
        self._table[key] = self.extractNodeOrDie(config, resource, key, typ)
      else:
        self._table[key] = self.extractNode(config, resource, key, typ)

  @staticmethod
  def extractNode(config, resource:tuple, key:str, typ=None):
    value = None
    for i in range(len(resource), -1, -1):
      l = list(resource[:i+1])
      if None in l: continue
      if value is None:
        value = config.get('.'.join(l+[key]), typ)

      if value is None:
        value = config.get('.'.join(l+['common', key]), typ)

    if value is None:
      value = config.get('.'.join([resource[0], 'defaults', key]), typ)

    return value

  def extractNodeOrDie(self, config, resource, key, typ=None):
    v = self.extractNode(config, resource, key, typ)
    assert v is not None, (str(resource)+'.'+key+' targets invalid or nonexistent node')
    return v

  def extractNodeOrDefault(self, config, resource, key, default, typ=None):
    v = self.extractNode(config, resource, key, typ)
    if v is None:
      v = default
    return v

  def _set(self, key, value):
    'allow manual override'
    self._table[key] = value
