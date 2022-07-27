#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Job(SubConfig):
  defaults = 'scenarios/base/job.yaml'
  baseKey = 'job'
  allVariables = [
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
    self.values = {}
    for v in self.allVariables:
      self.values[v] = config.getOrDie(v)

    #################################
    # auto-generate shell config file
    #################################
    cshVariables = self.allVariables
    cshStr = self.initCsh()
    for v in cshVariables:
      cshStr += self.varToCsh(v, self.values[v])

    self.write('config/job.csh', cshStr)

    ##################################
    # auto-generate cylc include files
    ##################################
    cylcVariables = self.allVariables
    cylcStr = []
    for v in cylcVariables:
      cylcStr += self.varToCylc(v, self.values[v])

    self.write('include/variables/auto/job.rc', cylcStr)
