#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class ExternalAnalyses(SubConfig):
  baseKey = 'externalanalyses'
  defaults = 'scenarios/base/externalanalyses.yaml'

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

  def __init__(self, config, meshes):
    super().__init__(config)

    csh = []
    cylc = ['GetGDASAnalysis']

    ###################
    # derived variables
    ###################
    resourceName = 'externalanalyses__resource'
    resource = self.get('resource')
    self._set(resourceName, resource)
    csh.append(resourceName)

    if resource is not None:
      for name, m in meshes.items():
        mesh = m.name
        nCells = str(m.nCells)

        for key in [
         'directory',
         'filePrefix',
         'PrepareExternalAnalysisTasks',
         'Vtable',
         'UngribPrefix',
        ]:
          value = self.extractResource(resource, mesh, key)

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
      self._set(variable, self.get('PrepareExternalAnalysisOuter'))
      cylc.append(variable)

    ###############################
    # export for use outside python
    ###############################
    self.exportVars(csh, cylc)

    RETRY = self.extractResource(resource, meshes['Outer'].name, 'retry')

    tasks = [
'''## Analyses generated outside MPAS-Workflow
  [[GetGFSAnalysisFromRDA]]
    inherit = BATCH
    script = $origin/applications/GetGFSAnalysisFromRDA.csh
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = '''+RETRY+'''
  [[GetGFSanalysisFromFTP]]
    inherit = BATCH
    script = $origin/applications/GetGFSAnalysisFromFTP.csh
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = '''+RETRY+'''
  [[GetGDASAnalysisFromFTP]]
    inherit = BATCH
    script = $origin/GetGDASAnalysisFromFTP.csh
    [[[job]]]
      execution time limit = PT45M
      execution retry delays = '''+RETRY+'''

  [[UngribExternalAnalysis]]
    inherit = BATCH
    script = $origin/applications/UngribExternalAnalysis.csh
    [[[job]]]
      execution time limit = PT5M
      execution retry delays = 2*PT30S
    # currently UngribExternalAnalysis has to be on Cheyenne, because ungrib.exe is built there
    # TODO: build ungrib.exe on casper, remove CP directives below
    [[[directives]]]
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}

  [[ExternalAnalysisReady]]
    inherit = BACKGROUND''']

    for mesh in list(set([mesh.name for mesh in meshes.values()])):
      tasks += [
'''
  [[LinkExternalAnalysis-'''+mesh+''']]
    inherit = BATCH
    script = $origin/applications/LinkExternalAnalysis.csh "'''+mesh+'''"
    [[[job]]]
      execution time limit = PT30S
      execution retry delays = '''+RETRY]

    self.exportTasks(tasks)
