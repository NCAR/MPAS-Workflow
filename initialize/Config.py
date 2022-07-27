#!/usr/bin/env python3

import argparse
from copy import deepcopy
import yaml

class Config():
  def __init__(self, conf, defaults=None, baseKey=None):
    with open(conf) as file:
      self.__conf = yaml.load(file, Loader=yaml.FullLoader)

    self.renew(defaults, baseKey)

  def renew(self, defaults=None, baseKey=None):
    if defaults is not None:
      with open(defaults) as file:
        d = yaml.load(file, Loader=yaml.FullLoader)
    else:
      d = None

    if baseKey is not None:
      if d is not None:
        self.defaults = d[baseKey]
      else:
        self.defaults = None
      self.conf = self.__conf[baseKey]
    else:
      if d is not None:
        self.defaults = d
      else:
        self.defaults = None

      self.conf = self.__conf

  def get(self, dotSeparatedKey):
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

    return v

  def getOrDefault(self, key, default):
    '''option to provide default value as second argument'''
    v = self.get(key)
    if v is None:
      return default
    else:
      return v

  def has(self, key):
    '''determine if config node is available'''
    v = self.get(key)
    return (v is not None)

  def getOrDie(self, key):
    '''throw error if node is not available'''
    v = self.get(key)
    assert v is not None, ('key ('+key+') is invalid or has None value')
    return v

  def getAsCsh(self, key):
    v = self.get(key)
    vsh = str(v)
    if isinstance(v, list):
      vsh = vsh.replace('\'','')
      vsh = vsh.replace('[','')
      vsh = vsh.replace(']','')
      vsh = vsh.replace(',',' ')
      #vsh = ' '+vsh+' '
    return vsh

  def getAsCshOrDie(self, key):
    vsh = self.getAsShell(key)
    assert vsh != 'None', ('key ('+key+') is invalid or has None value')
    return vsh
