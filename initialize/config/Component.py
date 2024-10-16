#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from collections.abc import Iterable

from initialize.config.Logger import Logger
from initialize.config.Config import Config
from initialize.config.TaskFamily import CylcTaskFamily
from initialize.config.SubConfig import SubConfig

class Component(Logger):

  defaults = None
  workDir = None
  requiredVariables = {}
  optionalVariables = {}
  variablesWithDefaults = {}
  def __init__(self, config:Config):

    super().__init__()

    self.base = self.__class__.__name__
    self.lower = self.__class__.__name__.lower()
    self.logPrefix = self.__class__.__name__+': '
    self.autoLabel = self.lower

    ######################################################
    # initialize exportable variables, tasks, dependencies
    ######################################################
    self._cshVars = []
    self._queues = []
    self._tasks = []
    self._dependencies = []

    ###################
    # extract SubConfig
    ###################
    self._conf = SubConfig.fromConfig(config, self.lower, self.defaults)

    ##############
    # parse config
    ##############
    self._vtable = {}
    for v, desc in self.requiredVariables.items():
      if isinstance(desc, Iterable):
        if len(desc) == 2:
          self._setOrDie(v, desc[0], desc[1])
      else:
        self._setOrDie(v, desc)

    for v, desc in self.optionalVariables.items():
      if isinstance(desc, Iterable):
        if len(desc) == 2:
          self._setOrNone(v, desc[0], desc[1])
      else:
        self._setOrNone(v, desc)

    # add initialize and execute variables to control internal TaskFamily object dependencies
    self.variablesWithDefaults['initialize'] = [False, bool] # overwritten when execute is True
    self.variablesWithDefaults['execute'] = [True, bool]

    for v, desc in self.variablesWithDefaults.items():
      if isinstance(desc, Iterable):
        if len(desc) == 2:
          self._setOrDefault(v, desc[0], desc[1])
        elif len(desc) == 3:
          self._setOrDefault(v, desc[0], desc[1], desc[2])
      else:
        self._setOrDefault(v, desc)

    # always precede execute with initialize
    if self['execute']:
      self._set('initialize', True)

    self.tf = CylcTaskFamily(self.base, [''], self['initialize'], self['execute'])


  def export(self):
    '''
    export for use outside python
    '''
    self._exportVarsToCsh()
    return

  def _msg(self, text, *args, **kwargs):
    self.log(text, *args, **kwargs)

  def __getitem__(self, key):
    '''
    basic _vtable get method
    usage: value = Component[key]
    '''
    return self._vtable[key]

  def _set(self, v, value):
    'basic _vtable set method'
    self._vtable[v] = value
    return

  ## methods for setting _vtable values from self._conf
  def _setOrDie(self, v, typ=None, options=None, vout=None):
    v_ = vout
    if v_ is None: v_ = v
    self._vtable[v_] = self._conf.getOrDie(v, typ, options)
    return

  def _setOrNone(self, v, typ=None, options=None, vout=None):
    v_ = vout
    if v_ is None: v_ = v
    self._vtable[v_] = self._conf.get(v, typ, options)
    return

  def _setOrDefault(self, v, default, typ=None, options=None, vout=None):
    v_ = vout
    if v_ is None: v_ = v
    self._vtable[v_] = self._conf.getOrDefault(v, default, typ, options)
    return

  ## general purpose nested extract methods
  def extractResource(self, resource:tuple, key:str, typ=None):
    value = None
    for i in range(len(resource), -1, -1):
      l = list(resource[:i+1])
      if None in l: continue
      if value is None:
        value = self._conf.get('.'.join(l+[key]), typ)

      if value is None:
        value = self._conf.get('.'.join(l+['common', key]), typ)

    if value is None:
      value = self._conf.get('.'.join([resource[0], 'defaults', key]), typ)

    return value

  def extractResourceOrDie(self, resource:tuple, key:str, typ=None):
    v = self.extractResource(resource, key, typ)
    assert v is not None, (str(resource)+'.'+key+' targets invalid or nonexistent node')
    return v

  def extractResourceOrDefault(self, resource:tuple, key:str, default, typ=None):
    v = self.extractResource(resource, key, typ)
    if v is None:
      v = default
    return v

  ## export methods
  @staticmethod
  def __toTextFile(filename, Str):
    #if len(Str) == 0: return
    #self._msg('Creating '+filename)
    with open(filename, 'w') as f:
      f.writelines(Str)
      f.close()
    return

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

  def _exportVarsToCsh(self):
    variables = self._cshVars
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
    self.__toTextFile('config/auto/'+self.lower+'.csh', Str)
    return
