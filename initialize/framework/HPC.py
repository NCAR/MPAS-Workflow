#!/usr/bin/env python3

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
    'CriticalAccount': ['NMMM0043', str],
    'CriticalQueue': ['regular', str],

    # NonCritical*: used non-critical path jobs, single or multi-node, multi-processor only
    'NonCriticalAccount': ['NMMM0043', str],
    'NonCriticalQueue': ['economy', str],

    # SingleProc*: used for single-processor jobs, both critical and non-critical paths
    # IMPORTANT: must NOT be executed on login node to comply with CISL requirements
    'SingleProcAccount': ['NMMM0015', str],
    'SingleProcQueue': ['casper@casper-pbs', str],
  }
  def __init__(self, config:Config):
    super().__init__(config)

    user = os.getenv('USER')
    TMPDIR = self['TMPDIR'].replace('{{USER}}', user)
    cmd = ['mkdir', '-p', TMPDIR]
    print(' '.join(cmd))
    sub = subprocess.run(cmd)

    # TODO: have all dependent classes take an HPC object as an argument, do not export
    self._cylcVars = list(self._vtable.keys())

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