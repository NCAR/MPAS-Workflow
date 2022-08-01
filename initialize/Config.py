#!/usr/bin/env python3

from copy import deepcopy
import yaml

class Config():
  def __init__(self, filename=None, defaultsFile=None, subKey=None):
    #self._filename = filename
    if filename is not None:
      with open(filename) as file:
        self.__conf = yaml.load(file, Loader=yaml.FullLoader)
    elif parent is not None and isinstance(parent, dict):
      self.__conf = parent

    self.renew(defaultsFile, subKey)

  def renew(self, defaultsFile=None, subKey=None):
    if defaultsFile is not None:
      with open(defaultsFile) as file:
        d = yaml.load(file, Loader=yaml.FullLoader)
    else:
      d = None

    if subKey is not None:
      try:
        self.defaults = d[subKey]
      except:
        self.defaults = None

      try:
        self.conf = self.__conf[subKey]
      except:
        self.conf = None

    else:
      self.defaults = d
      self.conf = self.__conf

  def get(self, dotSeparatedKey, t=None):
    '''
    get dictionary value for nested dot-separated key
    e.g., get('top.next') tries to retrieve self.conf['top']['next']
          if exception ocurrs, try to retrieve self.defaults['top']['next']
          if exception occurs, return None
    '''
    key = dotSeparatedKey.split('.')

    try:
      v = deepcopy(self.conf)
      for level in key:
        v = deepcopy(v[level])
    except:
      if self.defaults is not None:
        try:
          v = deepcopy(self.defaults)
          for level in key:
            v = deepcopy(v[level])
        except:
          v = None
      else:
        v = None

    if v is not None:
      if v == 'None': v = None

    if t is not None and v is not None:
      return t(v)
    else:
      return v

  def getOrDefault(self, key, default, t=None):
    '''option to provide default value as second argument'''
    v = self.get(key, t)
    if v is None:
      return default
    else:
      return v

  def has(self, key, t=None):
    '''determine if config node is available'''
    v = self.get(key, t)
    return (v is not None)

  def getOrDie(self, key, t=None):
    '''throw error if node is not available'''
    v = self.get(key, t)
    assert v is not None, ('key ('+key+') is invalid or has None value')
    return v
