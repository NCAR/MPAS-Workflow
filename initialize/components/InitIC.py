#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class InitIC(Component):
  defaults = 'scenarios/defaults/initic.yaml'

  def __init__(self, config, hpc, meshes, ea):
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

    for name, m in meshes.items():
      initArgs = '"'+ea['ExternalAnalysesDir'+name]+'"'
      initArgs += ' "'+ea['externalanalyses__filePrefix'+name]+'"'
      initArgs += ' "'+str(m.nCells)+'"'
      initArgs += ' "'+ea.WorkDir+'"'
      self._tasks += [
'''
  [[ExternalAnalysisToMPAS-'''+m.name+''']]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/ExternalAnalysisToMPAS.csh '''+initArgs+'''
'''+task.job()+task.directives()]

    #########
    # outputs
    #########
    self.outputs = {}
    for name, m in meshes.items():
      self.outputs[name] = [{
        'directory': ea['ExternalAnalysesDir'+name],
        'prefix': ea['externalanalyses__filePrefix'+name],
      }]
