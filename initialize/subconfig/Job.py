#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Job(SubConfig):
  defaults = 'scenarios/base/job.yaml'
  baseKey = 'job'
  baseVariables = [
    'CPAccountNumber',
    'CPQueueName',
    'NCPAccountNumber',
    'NCPQueueName',
    'SingleProcAccountNumber',
    'SingleProcQueueName',
    'EnsMeanBGQueueName',
    'EnsMeanBGAccountNumber',
  ]
  def __init__(self, config):
    super().__init__(config)

    ##############
    # parse config
    ##############
    for v in self.baseVariables:
      self.setOrDie(v)

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
