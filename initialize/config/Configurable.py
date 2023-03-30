#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from copy import deepcopy

class Configurable:
  conf = {}
  def __init__(self, conf:dict):
    '''
    conf: {key1[str]: {
              'def': default value, # optional
              'req': required, # bool, optional, False when missing
              'typ': type}, # e.g., int, float, str, list, class w/ ctor taking 1 arg
            key2[str]: {
              'def': default value, # optional
              'req': required, # bool, optional, False when missing
              'typ': type}, # e.g., int, float, str, list, class w/ ctor taking 1 arg
           }
    '''
    self.lower = self.__class__.__name__.lower()
    self.autoLabel = self.lower

    self._vtable = {}
    for k, v in self.conf.items():
      required = v.get('req', False)
      if required:
        assert k in conf, self.__class__.__name__+': missing conf element => '+str(k)

      vv = conf.get(k, v.get('def', None))

      if vv is not None:
        try:
          typ = v['typ']
          vv = typ(vv)
        except:
          raise TypeError

      self._vtable[k] = vv

  def __getitem__(self, key):
    '''
    basic get method
    usage: obj = Configurable(conf); value = obj[key]
    '''
    return self._vtable[key]
