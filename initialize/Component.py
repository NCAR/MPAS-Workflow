#!/usr/bin/env python3

from collections.abc import Iterable

from initialize.Config import Config
from initialize.SubConfig import SubConfig

class Component():
  baseKey = None
  defaults = None
  requiredVariables = {}
  optionalVariables = {}
  variablesWithDefaults = {}
  def __init__(self, config: Config):
    self.logPrefix = self.__class__.__name__+': '

    ###################
    # extract SubConfig
    ###################
    self._conf = SubConfig.fromConfig(config, self.baseKey, self.defaults)
    #assert self._conf is not None, self._msg('invalid baseKey: '+self.baseKey)

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
    return self.logPrefix+text

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
  def extractResource(self, resource1, resource2, key, t=None):
    if resource1 is None:
      r1 = ''
    else:
      r1 = resource1

    if resource2 is None:
      r2 = ''
    else:
      r2 = resource2

    value = self._conf.get('.'.join([r1, r2, key]), t)

    if value is None:
      value = self._conf.get('.'.join([r1, key]), t)

    if value is None:
      value = self._conf.get('.'.join([r1, 'common', key]), t)

    if value is None:
      value = self._conf.get('.'.join([r1, 'defaults', key]), t)

    if value is None:
      value = self._conf.get('.'.join(['defaults', key]), t)

    return value

  def extractResourceOrDie(self, r1, r2, key, t=None):
    v = self.extractResource(r1, r2, key, t)
    assert v is not None, (r1+', '+r2+', '+key+' targets invalid or nonexistent node')
    return v

  def extractResourceOrDefault(self, r1, r2, key, default, t=None):
    v = self.extractResource(r1, r2, key, t)
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
  def varToCsh(var, value):
    if isinstance(value, Iterable) and not isinstance(value, str):
      vsh = str(value)
      vsh = vsh.replace('\'','')
      vsh = vsh.replace('[','')
      vsh = vsh.replace(']','')
      vsh = vsh.replace(',',' ')
      return ['set '+var+' = ('+vsh+')\n']
    elif isinstance(var, str) and ' ' in var:
      parts = var.split(' ')
      vvar = ''.join([parts[0][0].lower()+parts[0][1:]]+[v.capitalize() for v in parts[1:]])
      return ['setenv '+vvar+' "'+str(value)+'"\n']
    else:
      return ['setenv '+var+' "'+str(value)+'"\n']

  def exportVarsToCsh(self, variables):
    if len(variables) == 0: return
    Str = ['''#!/bin/csh -f
######################################################
# THIS FILE IS AUTOMATICALLY GENERATED. DO NOT MODIFY.
# MODIFY THE SCENARIO YAML FILE INSTEAD.
######################################################

if ( $?config_'''+self.baseKey+''' ) exit 0
set config_'''+self.baseKey+''' = 1

''']
    for v in variables:
      Str += self.varToCsh(v, self._vtable[v])
    self.write('config/auto/'+self.baseKey+'.csh', Str)

  # cylc variables
  @staticmethod
  def varToCylc(var, value):
    if isinstance(value, str):
      return ['{% set '+var+' = "'+value+'" %}\n']
    else:
      return ['{% set '+var+' = '+str(value)+' %}\n']

  def exportVarsToCylc(self, variables):
    if len(variables) == 0: return
    Str = []
    for v in variables:
      Str += self.varToCylc(v, self._vtable[v])
    self.write('include/variables/auto/'+self.baseKey+'.rc', Str)

  # cylc dependencies
  def exportDependencies(self, text):
    self.write('include/dependencies/auto/'+self.baseKey+'.rc', text)

  # cylc tasks
  def exportTasks(self, text):
    self.write('include/tasks/auto/'+self.baseKey+'.rc', text)
