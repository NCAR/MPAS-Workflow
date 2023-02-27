#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class InitIC(Component):
  defaults = 'scenarios/defaults/initic.yaml'

  def __init__(self, config, hpc, meshes, externalanalyses):
    super().__init__(config)

    self.meshes = meshes
    self.baseTask = 'ExternalAnalysisToMPAS'
    self.__used = self.baseTask in externalanalyses['PrepareExternalAnalysisOuter']

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
    for typ in meshes.keys():
      self.outputs[typ] = [{
        'directory': externalanalyses['ExternalAnalysesDir'+typ],
        'prefix': externalanalyses['externalanalyses__filePrefix'+typ],
      }]

  def export(self, components):
    if 'extendedforecast' in components:
      dtOffsets=components['extendedforecast']['extLengths']
    else:
      dtOffsets=[0]

    subqueues = []
    if self.__used:
      # only once for each mesh
      meshTypes = []
      meshNames = []
      meshNCells = []
      for typ, mesh in self.meshes.items():
        if mesh.name not in meshNames:
          meshTypes.append(typ)
          meshNames.append(mesh.name)
          meshNCells.append(mesh.nCells)

      queue = 'ConvertExternalAnalyses'
      subqueues.append(queue)
      for (typ, meshName, nCells) in zip(meshTypes, meshNames, meshNCells):
        prevTaskName = None
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
          taskName = self.baseTask+'-'+meshName+'-'+dtStr+'hr'

          self._tasks += ['''
  [['''+taskName+''']]
    inherit = ConvertExternalAnalyses, BATCH
    script = $origin/applications/ExternalAnalysisToMPAS.csh '''+initArgs+'''
'''+self.__task.job()+self.__task.directives()]

          # make task[t+dt] depend on task[t]
          if prevTaskName is not None:
            # special catch-all succeed string needed due to 0hr naming below
            if dtOffsets[0] == 0 and dtOffsets.index(dt) == 1:
              success = ':succeed-all'
            else:
              success = ''

            self._dependencies += ['''
    '''+prevTaskName+success+''' => '''+taskName]

          prevTaskName = taskName

        # generic 0hr task names for external classes/tasks to grab
        self._tasks += ['''
  [['''+self.baseTask+'''-'''+meshName+''']]
    inherit = '''+self.baseTask+'''-'''+meshName+'''-0hr''']

    # only 1 task per subqueue to avoid cross-cycle errors
    for queue in set(subqueues):
      self._tasks += ['''
  [['''+queue+''']]
    inherit = '''+self.groupName]

      self._queues += ['''
    [[['''+queue+''']]]
      members = '''+queue+'''
      limit = 1''']

    super().export(components)
