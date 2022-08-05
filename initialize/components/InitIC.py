#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class InitIC(Component):
  defaults = 'scenarios/defaults/initic.yaml'

  def __init__(self, config, hpc, meshes):
    super().__init__(config)

    ########################
    # tasks and dependencies
    ########################
    # job settings
    attr = {
      'retry': {'t': str},
      'seconds': {'t': int},
      'nodes': {'t': int},
      'PEPerNode': {'t': int},
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
    }
    job = Resource(self._conf, attr, ('job', meshes['Outer'].name))
    task = TaskFactory[hpc.system](job)

    tasks = []
    for mesh in list(set([mesh.name for mesh in meshes.values()])):
      tasks += [
'''
  [[ExternalAnalysisToMPAS-'''+mesh+''']]
    inherit = BATCH
    script = $origin/applications/ExternalAnalysisToMPAS.csh "'''+mesh+'''"
'''+task.job()+task.directives()]

    self.exportTasks(tasks)
