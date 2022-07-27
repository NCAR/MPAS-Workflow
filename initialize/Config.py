#!/usr/bin/env python3

import argparse
from copy import deepcopy
import yaml

class Config():
  def __init__(self, defaults, scenario, baseKey):
    with open(defaults) as file:
      d = yaml.load(file, Loader=yaml.FullLoader)

    with open(scenario) as file:
      self.__scenario = yaml.load(file, Loader=yaml.FullLoader)

    self.reset(d, baseKey)

  def reset(self, defaults, baseKey):
    self.defaults = defaults[baseKey]
    self.scenario = self.__scenario[baseKey]

  def get(self, dotSeparatedKey):
    '''
    get dictionary value for nested dot-separated key
    e.g., get('top.next') tries to retrieve self.scenario['top']['next']
          if exception ocurrs, try to retrieve self.defaults['top']['next']
          if exception occurs, return None
    '''
    key = dotSeparatedKey.split('.')

    try:
      v = deepcopy(self.scenario)
      for level in key:
        v = deepcopy(v[level])
        #k = level
    except:
      try:
        v = deepcopy(self.defaults)
        for level in key:
          v = deepcopy(v[level])
          #k = level
      except:
        v = None
        #k = None

    return v

  def getOrDie(self, key):
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
