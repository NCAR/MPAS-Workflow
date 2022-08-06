#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class ExternalAnalyses(Component):
  defaults = 'scenarios/defaults/externalanalyses.yaml'
  workDir = 'ExternalAnalyses'
  optionalVariables = {
    ## resource:
    # used to select from among available options (e.g., see defaults)
    # must be in quotes
    # e.g., "GFS.RDA", "GFS.NCEPFTP", "GFS.PANDAC"
    'resource': str,
  }
  variablesWithDefaults = {
    # Get GDAS analyses
    'GetGDASAnalysis': [False, bool]
  }

  def __init__(self, config, hpc, meshes):
    super().__init__(config)

    csh = []
    cylc = ['GetGDASAnalysis']

    ###################
    # derived variables
    ###################
    resourceName = 'externalanalyses__resource'
    resource = self['resource']
    self._set(resourceName, resource)
    csh.append(resourceName)

    if resource is not None:
      for name, m in meshes.items():
        mesh = m.name
        nCells = str(m.nCells)

        for (key, t) in [
         ['directory', str],
         ['filePrefix', str],
         ['PrepareExternalAnalysisTasks', list],
         ['Vtable', str],
         ['UngribPrefix', str],
        ]:
          value = self.extractResource(('resources', resource, mesh), key, t)

          if key == 'PrepareExternalAnalysisTasks':
            # push back cylc mini-workflow variables
            values = [task.replace('{{mesh}}',mesh) for task in value]

            # first add variable as a list of tasks
            variable = key+name
            cylc.append(variable)
            self._set(variable, values)

            # then add as a joined string with dependencies between subtasks (" => ")
            # e.g.,
            # variable: PrepareExternalAnalysisTasksOuter becomes PrepareExternalAnalysisOuter
            # value: [a, b] becomes "a => b"
            variable = variable.replace('Tasks','')
            value = " => ".join(values)
            cylc.append(variable)
            self._set(variable, value)
            continue

          else:
            # auto-generated csh variables
            variable = 'externalanalyses__'+key+name
            if key in ['Vtable','UngribPrefix']:
              if name == 'Outer':
                variable = 'externalanalyses__'+key
              else:
                continue
            
            if key == 'filePrefix' and isinstance(value, str):
              value = value.replace('{{nCells}}', nCells)

            self._set(variable, value)
            csh.append(variable)

      # Use external analysis for sea surface updating
      variable = 'PrepareSeaSurfaceUpdate'
      self._set(variable, self['PrepareExternalAnalysisOuter'])
      cylc.append(variable)

    ###############################
    # export for use outside python
    ###############################
    self.exportVarsToCsh(csh)
    self.exportVarsToCylc(cylc)

    ########################
    # tasks and dependencies
    ########################
    getRetry = self.extractResourceOrDie(('resources', resource), 'job.GetAnalysisFrom.retry', str)

    attr = {
      'seconds': {'def': 300},
      'retry': {'def': '2*PT30S'},
      # currently UngribExternalAnalysis has to be on Cheyenne, because ungrib.exe is built there
      # TODO: build ungrib.exe on casper, remove Critical directives below, deferring to
      #       SingleBatch inheritance
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
    }
    ungribjob = Resource(self._conf, attr, ('job', 'ungrib'))
    ungribtask = TaskFactory[hpc.system](ungribjob)

    self.groupName = self.__class__.__name__
    tasks = [
'''## Analyses generated outside MPAS-Workflow
  [['''+self.groupName+''']]
  [[GetGFSAnalysisFromRDA]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/GetGFSAnalysisFromRDA.csh
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = '''+getRetry+'''
  [[GetGFSanalysisFromFTP]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/GetGFSAnalysisFromFTP.csh
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = '''+getRetry+'''
  [[GetGDASAnalysisFromFTP]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/GetGDASAnalysisFromFTP.csh
    [[[job]]]
      execution time limit = PT45M
      execution retry delays = '''+getRetry+'''

  [[UngribExternalAnalysis]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/UngribExternalAnalysis.csh
'''+ungribtask.job()+ungribtask.directives()+'''

  [[LinkExternalAnalyses]]
    inherit = '''+self.groupName+'''
  [[ExternalAnalysisReady]]
    inherit = '''+self.groupName+''', BACKGROUND''']

    for mesh in list(set([mesh.name for mesh in meshes.values()])):
      tasks += [
'''
  [[LinkExternalAnalysis-'''+mesh+''']]
    inherit = LinkExternalAnalyses, SingleBatch
    script = $origin/applications/LinkExternalAnalysis.csh "'''+mesh+'''"
    [[[job]]]
      execution time limit = PT30S
      execution retry delays = 1*PT30S''']

    self.exportTasks(tasks)
