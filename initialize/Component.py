#!/usr/bin/env python3

from collections.abc import Iterable

from initialize.Config import Config
from initialize.SubConfig import SubConfig

class Component():
  defaults = None
  workDir = None
  requiredVariables = {}
  optionalVariables = {}
  variablesWithDefaults = {}
  def __init__(self, config:Config):
    self.lower = self.__class__.__name__.lower()
    self.logPrefix = self.__class__.__name__+': '

    ###################
    # extract SubConfig
    ###################
    self._conf = SubConfig.fromConfig(config, self.lower, self.defaults)

    ##############
    # parse config
    ##############
    self._vtable = {}
    for v, t in self.requiredVariables.items():
      self._setOrDie(v, t)

    for v, t in self.optionalVariables.items():
      self._setOrNone(v, t)

    for v, a in self.variablesWithDefaults.items():
      self._setOrDefault(v, a[0], a[1])

  def _msg(self, text):
    print(self.logPrefix+text)

  def __getitem__(self, key):
    '''
    basic _vtable get method
    usage: value = Component[key]
    '''
    return self._vtable[key]

  def _set(self, v, value):
    'basic _vtable set method'
    self._vtable[v] = value

  ## methods for setting _vtable values from self._conf
  def _setOrDie(self, v, t=None, vout=None):
    v_ = vout
    if v_ is None: v_ = v
    self._vtable[v_] = self._conf.getOrDie(v, t)

  def _setOrNone(self, v, t=None, vout=None):
    v_ = vout
    if v_ is None: v_ = v
    self._vtable[v_] = self._conf.get(v, t)

  def _setOrDefault(self, v, default, t=None, vout=None):
    v_ = vout
    if v_ is None: v_ = v
    self._vtable[v_] = self._conf.getOrDefault(v, default, t)

  ## general purpose nested extract methods
  def extractResource(self, resource:tuple, key:str, t=None):
    value = None
    for i in range(len(resource), -1, -1):
      l = list(resource[:i+1])
      if None in l: continue
      if value is None:
        value = self._conf.get('.'.join(l+[key]), t)

      if value is None:
        value = self._conf.get('.'.join(l+['common', key]), t)

    if value is None:
      value = self._conf.get('.'.join([resource[0], 'defaults', key]), t)

    return value

  def extractResourceOrDie(self, resource:tuple, key:str, t=None):
    v = self.extractResource(resource, key, t)
    assert v is not None, (str(resource)+'.'+key+' targets invalid or nonexistent node')
    return v

  def extractResourceOrDefault(self, resource:tuple, key:str, default, t=None):
    v = self.extractResource(resource, key, t)
    if v is None:
      v = default
    return v

  ## export methods
  @staticmethod
  def write(filename, Str):
     if len(Str) == 0: return
     #self._msg('Creating '+filename)
     with open(filename, 'w') as f:
       f.writelines(Str)
       f.close()

  # csh variables
  @staticmethod
  def varToCsh(var:str, value):
    vvar = var
    if ' ' in var:
      parts = var.split(' ')
      vvar = ''.join([parts[0][0].lower()+parts[0][1:]]+[v.capitalize() for v in parts[1:]])

    if isinstance(value, Iterable) and not isinstance(value, str):
      vsh = str(value)
      vsh = vsh.replace('\'','')
      vsh = vsh.replace('[','')
      vsh = vsh.replace(']','')
      vsh = vsh.replace(',',' ')
      return ['set '+vvar+' = ('+vsh+')\n']
    else:
      return ['setenv '+vvar+' "'+str(value)+'"\n']

  def exportVarsToCsh(self, variables):
    if len(variables) == 0: return
    Str = ['''#!/bin/csh -f
######################################################
# THIS FILE IS AUTOMATICALLY GENERATED. DO NOT MODIFY.
# MODIFY THE SCENARIO YAML FILE INSTEAD.
######################################################

if ( $?config_'''+self.lower+''' ) exit 0
set config_'''+self.lower+''' = 1

''']
    for v in variables:
      Str += self.varToCsh(v, self._vtable[v])
    self.write('config/auto/'+self.lower+'.csh', Str)

  # cylc variables
  @staticmethod
  def varToCylc(var:str, value):
    vvar = var
    if ' ' in var:
      parts = var.split(' ')
      vvar = ''.join([parts[0][0].lower()+parts[0][1:]]+[v.capitalize() for v in parts[1:]])

    if isinstance(value, str):
      return ['{% set '+vvar+' = "'+value+'" %}\n']
    else:
      return ['{% set '+vvar+' = '+str(value)+' %}\n']

  def exportVarsToCylc(self, variables):
    if len(variables) == 0: return
    Str = []
    for v in variables:
      Str += self.varToCylc(v, self._vtable[v])
    self.write('include/variables/auto/'+self.lower+'.rc', Str)

  # cylc dependencies
  def exportDependencies(self, text):
    self.write('include/dependencies/auto/'+self.lower+'.rc', text)

  # cylc tasks
  def exportTasks(self, text):
    self.write('include/tasks/auto/'+self.lower+'.rc', text)
