#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Job(SubConfig):
  baseKey = 'job'
  requiredVariables = {
  }
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

    ###################
    # derived variables
    ###################

    # EMPTY

    #################################
    # auto-generate shell config file
    #################################
    cshVariables = list(self._table.keys())
    cshStr = self.initCsh()
    for v in cshVariables:
      cshStr += self.varToCsh(v, self._table[v])

    self.write('config/job.csh', cshStr)

    ##################################
    # auto-generate cylc include files
    ##################################
    cylcVariables = list(self._table.keys())
    cylcStr = []
    for v in cylcVariables:
      cylcStr += self.varToCylc(v, self._table[v])

    self.write('include/variables/auto/job.rc', cylcStr)