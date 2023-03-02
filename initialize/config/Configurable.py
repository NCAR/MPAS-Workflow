#!/usr/bin/env python3

from copy import deepcopy

class Configurable:
  conf = {}
  def __init__(self, conf:dict):
    self.lower = self.__class__.__name__.lower()
    self.autoLabel = self.lower

    self._conf = {}
    for k, v in self.conf.items():
      required = v.get('required', False)
      if required:
        assert k in conf, self.__class__.__name__+': missing conf element => '+str(k)

      vv = conf.get(k, v.get('default', None))

      typ = v['typ']
      if vv is not None:
        try:
          vv = typ(v)
        except:
          raise TypeError

      self._conf[k] = vv

  def __getitem__(self, key):
    '''
    basic get method
    usage: obj = Configurable(conf); value = obj[key]
    '''
    return self._conf[key]
