#!/usr/bin/env python3

from initialize.Component import Component

class Job(Component):
  baseKey = 'job'
  variablesWithDefaults = {
    ## *AccountNumber
    # OPTIONS: NMMM0015, NMMM0043
    #Note: NMMM0043 is not available on casper

    ## *QueueName
    # Cheyenne Options: economy, regular, premium
    # Casper Options: casper@casper-pbs

    # CP*: used for all critical path jobs, single or multi-node, multi-processor only
    'CPAccountNumber': ['NMMM0043', str],
    'CPQueueName': ['regular', str],

    # NCP*: used non-critical path jobs, single or multi-node, multi-processor only
    'NCPAccountNumber': ['NMMM0043', str],
    'NCPQueueName': ['economy', str],

    # SingleProc*: used for single-processor jobs, both critical and non-critical paths
    # IMPORTANT: must NOT be executed on login node to comply with CISL requirements
    #SingleProcAccountNumber': ['NMMM0043', str],
    #SingleProcQueueName': ['share', str],
    'SingleProcAccountNumber': ['NMMM0015', str],
    'SingleProcQueueName': ['casper@casper-pbs', str],

    # EnsMeanBG*: settings for ensemble mean BG calculation; useful for override when time-critical
    'EnsMeanBGAccountNumber': ['NMMM0043', str],
    'EnsMeanBGQueueName': ['economy', str],
  }
  def __init__(self, config):
    super().__init__(config)

    ###############################
    # export for use outside python
    ###############################
    # TODO: have all dependent classes take a Job object as an argument, do not export
    cylc = list(self._vtable.keys())
    self.exportVarsToCylc(cylc)
