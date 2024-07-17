#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

import os
import subprocess

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

class HPC(Component):
  system = 'cheyenne'
  variablesWithDefaults = {
    # override these below based on host
    'top directory': ['/glade/scratch', str],
    'TMPDIR': ['/glade/scratch/{{USER}}/temp', str],

    # TODO: place these configuration elements in a user- and/or hpc-specific resource
    ## *Account
    # EXAMPLES: NMMM0015, NMMM0043

    ## *Queue
    # Cheyenne Options: economy, regular, premium
    # Casper Options: casper@casper-pbs
    # Derecho options: main

    # Critical*: used for all critical path jobs, single or multi-node, multi-processor only
    'CriticalAccount': ['NMMM0015', str],
    # override this below based on host
    'CriticalQueue': ['regular', str, ['economy', 'regular', 'premium']],

    # NonCritical*: used non-critical path jobs, single or multi-node, multi-processor only
    'NonCriticalAccount': ['NMMM0015', str],
    # override this below based on host
    'NonCriticalQueue': ['economy', str, ['economy', 'regular', 'premium']],

    # SingleProc*: used for single-processor jobs, both critical and non-critical paths
    # IMPORTANT: must NOT be executed on login node to comply with CISL requirements
    'SingleProcAccount': ['NMMM0015', str],
    'SingleProcQueue': ['casper@casper-pbs', str, ['casper@casper-pbs', 'share']],
  }
  def __init__(self, config:Config):
    self.logPrefix = self.__class__.__name__+': '

    # set system dependent defaults before invoking Component ctor
    system = os.getenv('NCAR_HOST')
    if system == 'derecho':
      topdir = '/glade/derecho/scratch'
      self.variablesWithDefaults['CriticalQueue'] = ['main', str, ['main', 'preempt']]
      self.variablesWithDefaults['NonCriticalQueue'] =  ['main', str, ['main', 'preempt']]
#      self.variablesWithDefaults['SingleProcQueue'] = ['casper@casper-pbs', str, ['casper@casper-pbs', 'main']]
      self.variablesWithDefaults['priority'] = ['regular', str, ['premium', 'regular', 'economy', 'preempt']]
      self.system = system
      #config.convertToDerecho()
    elif system == 'cheyenne':
      topdir = '/glade/scratch'
      self.variablesWithDefaults['CriticalQueue'] = \
          ['regular', str, ['economy', 'regular', 'premium']]
      self.variablesWithDefaults['NonCriticalQueue'] = \
          ['economy', str, ['economy', 'regular', 'premium']]
      self.system = system
    else:
      self._msg('unknown host:' + system)
      topdir = '/tmp'

    self.variablesWithDefaults['top directory'] = [topdir, str]
    self.variablesWithDefaults['TMPDIR'] = [topdir + '/{{USER}}/temp', str]
    self._msg('vars'+ str(self.variablesWithDefaults))
    self._msg('init######################################################################')
    #print('config:', dir(config))
    #self._msg('table:'+ str(config._table))
    super().__init__(config)

    user = os.getenv('USER')
    TMPDIR = self['TMPDIR'].replace('{{USER}}', user)
    cmd = ['mkdir', '-p', TMPDIR]
    print(' '.join(cmd))
    sub = subprocess.run(cmd)

    # default multi-processor task
    attr = {
      'seconds': {'def': 3600},
    }
    multijob = Resource(self._conf, attr, ('job', 'multi proc'))
    self.multitask = TaskLookup[self.system](multijob)

    # default single-processor task
    attr = {
      'seconds': {'def': 3600},
      'nodes': {'def': 1, 'typ': int},
      'PEPerNode': {'def': 1, 'typ': int},
      'queue': {'def': self['SingleProcQueue']},
      'account': {'def': self['SingleProcAccount']},
    }
    singlejob = Resource(self._conf, attr, ('job', 'single proc'))
    self.singletask = TaskLookup[self.system](singlejob)

  def maxMemPerNode(self):
    return self.multitask.maxMemPerNode

  def maxProcPerNode(self):
    return self.multitask.maxProcPerNode
