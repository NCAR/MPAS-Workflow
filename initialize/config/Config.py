#!/usr/bin/env python3

from collections.abc import Iterable
from copy import deepcopy
import yaml

class Config():
  def __init__(self,
      filename: str,
      defaultsFile:str = None,
    ):

   with open(filename) as file:
     self._table = yaml.load(file, Loader=yaml.FullLoader)

   if defaultsFile is not None:
     with open(defaultsFile) as file:
       self._defaults = yaml.load(file, Loader=yaml.FullLoader)
   else:
     self._defaults = {}

  def extract(self, subKey: str, defaultsFile:str = None):
    t = deepcopy(self._table.get(subKey, {}))

    if defaultsFile is not None:
      with open(defaultsFile) as file:
        defaults = yaml.load(file, Loader=yaml.FullLoader)
      d = defaults.get(subKey, {})
    else:
      d = deepcopy(self._defaults.get(subKey, {}))

    return t, d

  def get(self, dotSeparatedKey, t=None, options=None):
    '''
    get dictionary value for nested dot-separated key
    e.g., get('top.next') tries to retrieve self._table['top']['next']
          if exception ocurrs, try to retrieve self.defaults['top']['next']
          if exception occurs, return None
    '''
    key = dotSeparatedKey.split('.')

    try:
      v = deepcopy(self._table)
      for level in key:
        v = deepcopy(v[level])
    except:
      try:
        v = deepcopy(self._defaults)
        for level in key:
          v = deepcopy(v[level])
      except:
        v = None
    if v is not None:
      if v == 'None': v = None

    if options is not None and v is not None:
      assert isinstance(options, Iterable) and not isinstance(options, str), (
        'options must be a list of valid values or not present at all, not '+str(options))
      assert v in options, ('invalid value for '+dotSeparatedKey+': '+str(v)+
        '; choose one of '+str(options))

    if t is not None and v is not None:
      return t(v)
    else:
      return v

  def __getitem__(self, key:str):
    return self.get(key)

  def __setitem__(self, key:str, v):
    self._table[key] = v

  def getOrDefault(self, key, default, t=None, options=None):
    '''option to provide default value as second argument'''
    v = self.get(key, t, options)
    if v is None:
      return default
    else:
      return v

  def has(self, key, t=None, options=None):
    '''determine if config node is available and has valid value'''
    v = self.get(key, t, options)
    return (v is not None)

  def getOrDie(self, key, t=None, options=None):
    '''throw error if node is not available'''
    v = self.get(key, t, options)
    assert v is not None, ('key ('+key+') is invalid or has None value')
    return v
