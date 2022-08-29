#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class InitIC(Component):
  defaults = 'scenarios/defaults/initic.yaml'

  def __init__(self, config, hpc, meshes, externalanalyses):
    super().__init__(config)

    self.meshes = meshes

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
    self.__task = TaskFactory[hpc.system](job)

    self.groupName = externalanalyses.groupName

    #########
    # outputs
    #########
    self.outputs = {}
    for typ, m in meshes.items():
      self.outputs[typ] = [{
        'directory': externalanalyses['ExternalAnalysesDir'+typ],
        'prefix': externalanalyses['externalanalyses__filePrefix'+typ],
      }]

  def export(self, components):
    if 'extendedforecast' in components:
      dtOffsets=components['extendedforecast']['extLengths']
    else:
      dtOffsets=[0]

    meshTypes = []
    meshNames = []
    meshNCells = []
    for typ, m in self.meshes.items():
      if m.name not in meshNames:
        meshTypes.append(typ)
        meshNames.append(m.name)
        meshNCells.append(m.nCells)

    self._tasks = []
    for (typ, name, nCells) in zip(meshTypes, meshNames, meshNCells):
      for dt in dtOffsets:
        dtStr = str(dt)
        args = [
          dt,
          components['externalanalyses']['ExternalAnalysesDir'+typ],
          components['externalanalyses']['externalanalyses__filePrefix'+typ],
          nCells,
          components['externalanalyses'].WorkDir,
        ]
        initArgs = ' '.join(['"'+str(a)+'"' for a in args])
        self._tasks += [
'''
  [[ExternalAnalysisToMPAS-'''+name+'''-'''+dtStr+'''hr]]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/ExternalAnalysisToMPAS.csh '''+initArgs+'''
'''+self.__task.job()+self.__task.directives()]

      self._tasks += [
'''
  [[ExternalAnalysisToMPAS-'''+name+''']]
    inherit = ExternalAnalysisToMPAS-'''+name+'''-0hr''']

    super().export(components)
