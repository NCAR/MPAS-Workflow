#!/usr/bin/env python3

import os
import subprocess

from initialize.Component import Component

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
    'CriticalQueue': ['regular', str, ['economy', 'regular', 'premium']],

    # NonCritical*: used non-critical path jobs, single or multi-node, multi-processor only
    'NonCriticalAccount': ['NMMM0043', str],
    'NonCriticalQueue': ['economy', str, ['economy', 'regular', 'premium']],

    # SingleProc*: used for single-processor jobs, both critical and non-critical paths
    # IMPORTANT: must NOT be executed on login node to comply with CISL requirements
    'SingleProcAccount': ['NMMM0015', str],
    'SingleProcQueue': ['casper@casper-pbs', str, ['casper@casper-pbs']],

    # EnsMeanBG*: settings for ensemble mean BG calculation; useful for override when time-critical
    'EnsMeanBGAccount': ['NMMM0043', str],
    'EnsMeanBGQueue': ['economy', str, ['economy', 'regular', 'premium']],
  }
  def __init__(self, config):
    super().__init__(config)

    user = os.getenv('USER')
    TMPDIR = self['TMPDIR'].replace('{{USER}}', user)
    cmd = ['mkdir', '-p', TMPDIR]
    print(' '.join(cmd))
    sub = subprocess.run(cmd)

    # TODO: have all dependent classes take an HPC object as an argument, do not export
    self._cylcVars = list(self._vtable.keys())
