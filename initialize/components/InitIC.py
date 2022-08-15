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

    self.groupName = self.__class__.__name__
    self._tasks = ['''
  [['''+self.groupName+']]']

    for mesh in list(set([mesh.name for mesh in meshes.values()])):
      self._tasks += [
'''
  [[ExternalAnalysisToMPAS-'''+mesh+''']]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/ExternalAnalysisToMPAS.csh "'''+mesh+'''"
'''+task.job()+task.directives()]
