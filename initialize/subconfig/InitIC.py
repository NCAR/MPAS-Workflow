#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class InitIC(SubConfig):
  baseKey = 'initic'
  defaults = 'scenarios/defaults/initic.yaml'

  def __init__(self, config, meshes):
    super().__init__(config)

    csh = []
    cylc = []

    ###################
    # derived variables
    ###################
    retry = self.extractResourceOrDie('job', None, 'retry')
    seconds = str(int(self.extractResourceOrDie('job', meshes['Outer'].name, 'seconds')))
    nodes = str(int(self.extractResourceOrDie('job', meshes['Outer'].name, 'nodes')))
    PEPerNode = str(int(self.extractResourceOrDie('job', meshes['Outer'].name, 'PEPerNode')))

    ###############################
    # export for use outside python
    ###############################
    self.exportVars(csh, cylc)

    tasks = []
    for mesh in list(set([mesh.name for mesh in meshes.values()])):
      tasks += [
'''
  [[ExternalAnalysisToMPAS-'''+mesh+''']]
    inherit = BATCH
    script = $origin/applications/ExternalAnalysisToMPAS.csh "'''+mesh+'''"
    [[[job]]]
      execution time limit = PT'''+seconds+'''S
      execution retry delays = '''+retry+'''
    [[[directives]]]
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select='''+nodes+':ncpus='+PEPerNode+':mpiprocs='+PEPerNode]

    self.exportTasks(tasks)
