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
    'top directory': ['/glade/scratch', str],
    'TMPDIR': ['/glade/scratch/{{USER}}/temp', str],

    # TODO: place these configuration elements in a user- and/or hpc-specific resource
    ## *Account
    # EXAMPLES: NMMM0015, NMMM0043

    ## *Queue
    # Cheyenne Options: economy, regular, premium
    # Casper Options: casper@casper-pbs

    # Critical*: used for all critical path jobs, single or multi-node, multi-processor only
    'CriticalAccount': ['UCSD0041', str],
    'CriticalQueue': ['regular', str, ['economy', 'regular', 'premium']],

    # NonCritical*: used non-critical path jobs, single or multi-node, multi-processor only
    'NonCriticalAccount': ['UCSD0041', str],
    'NonCriticalQueue': ['economy', str, ['economy', 'regular', 'premium']],

    # SingleProc*: used for single-processor jobs, both critical and non-critical paths
    # IMPORTANT: must NOT be executed on login node to comply with CISL requirements
    'SingleProcAccount': ['UCSD0041', str],
    'SingleProcQueue': ['economy', str, ['economy', 'regular', 'premium']], #['casper@casper-pbs', str, ['casper@casper-pbs', 'share']],
  }
  def __init__(self, config:Config):
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
