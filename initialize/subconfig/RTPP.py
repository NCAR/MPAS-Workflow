#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class RTPP(SubConfig):
  baseKey = 'rtpp'
  defaults = 'scenarios/defaults/rtpp.yaml'
  workDir = 'CyclingInflation/RTPP'

  variablesWithDefaults = {
    ## relaxationFactor
    # parameter for the relaxation to prior perturbation (RTPP) mechanism
    # only applies to EDA cycling and must be set in order to use RTPP
    # Typical Values: 0. to 0.9
    'relaxationFactor': [0., float],

    ## retainOriginalAnalyses
    # whether to retain the analyses taken as inputs to RTPP
    # OPTIONS: True/False
    'retainOriginalAnalyses': [False, bool],
  }

  def __init__(self, config, ensMesh, members, da):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    self._set('appyaml', 'rtpp.yaml')
    relaxationFactor = self.get('relaxationFactor')
    assert relaxationFactor >= 0. and relaxationFactor <= 1., (
      self._msg('invalid relaxationFactor: '+str(relaxationFactor)))

    # used by experiment naming convention
    self._set('rtpp__relaxationFactor', relaxationFactor)

    active = (relaxationFactor > 0. and members.n > 1)

    ###############################
    # export for use outside python
    ###############################
    if active:
      csh = list(self._vtable.keys())
      self.exportVarsToCsh(csh)

    ########################
    # tasks and dependencies
    ########################
    self.tasks = ['#']
    self.dependencies = ['#']
    if active:
      retry = self.extractResourceOrDie('job', None, 'retry', str)

      meshKey = ensMesh.name
      baseSeconds = self.extractResourceOrDie('job', meshKey, 'baseSeconds', int)
      secondsPerMember = self.extractResourceOrDie('job', meshKey, 'secondsPerMember', int)
      seconds = str(baseSeconds + secondsPerMember * members.n)

      nodes = self.extractResourceOrDie('job', meshKey, 'nodes', int)
      PEPerNode = self.extractResourceOrDie('job', meshKey, 'PEPerNode', int)
      memory = self.extractResourceOrDie('job', meshKey, 'memory', str)

      self.tasks += ['''
  [[PrepRTPP]]
    # note: does not depend on any other tasks
    inherit = SingleBatch
    script = $origin/applications/PrepRTPP.csh
    [[[job]]]
      execution time limit = PT1M
      execution retry delays = '''+retry+'''
  [[RTPP]]
    inherit = BATCH
    script = $origin/applications/RTPP.csh
    [[[job]]]
      execution time limit = PT'''+str(seconds)+'''S
      execution retry delays = '''+retry+'''
    [[[directives]]]
      -m = ae
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select='''+str(nodes)+':ncpus='+str(PEPerNode)+':mpiprocs='+str(PEPerNode)+':mem='+memory+'''

  [[CleanRTPP]]
    inherit = '''+da.clean+''', CleanBase
    script = $origin/applications/CleanRTPP.csh''']

      self.dependencies += ['''
        PrepRTPP => RTPP
        '''+da.post+''' => RTPP => '''+da.finished]
