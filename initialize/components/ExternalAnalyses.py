#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class ExternalAnalyses(Component):
  defaults = 'scenarios/defaults/externalanalyses.yaml'
  workDir = 'ExternalAnalyses'
  requiredVariables = {
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

    ###################
    # derived variables
    ###################
    resourceName = 'externalanalyses__resource'
    resource = self['resource']
    self._set(resourceName, resource)
    self._cshVars.append(resourceName)

    # WorkDir is where external analysis files are linked/downloaded, e.g., in grib format
    self.WorkDir = self.workDir+'/'+resource+'/{{thisValidDate}}'

    for name, m in meshes.items():
      mesh = m.name
      nCells = str(m.nCells)
      # 'ExternalAnalysesDir'+name is where external analyses converted to MPAS meshes are
      # created and/or stored
      self._set('ExternalAnalysesDir'+name, self.workDir+'/'+mesh+'/{{thisValidDate}}')
      self._cshVars.append('ExternalAnalysesDir'+name)

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
          self._cylcVars.append(variable)
          self._set(variable, values)

          # then add as a joined string with dependencies between subtasks (" => ")
          # e.g.,
          # variable: PrepareExternalAnalysisTasksOuter becomes PrepareExternalAnalysisOuter
          # value: [a, b] becomes "a => b"
          variable = variable.replace('Tasks','')
          value = " => ".join(values)
          self._cylcVars.append(variable)
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
          self._cshVars.append(variable)

    # Use external analysis for sea surface updating
    variable = 'PrepareSeaSurfaceUpdate'
    self._set(variable, self['PrepareExternalAnalysisOuter'])
    self._cylcVars.append(variable)

    self._cylcVars += ['GetGDASAnalysis']

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

    self._tasks = [
'''## Analyses generated outside MPAS-Workflow
  [['''+self.groupName+''']]
  [[GetGFSAnalysisFromRDA]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/GetGFSAnalysisFromRDA.csh "'''+self.WorkDir+'''"
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = '''+getRetry+'''
  [[GetGFSanalysisFromFTP]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/GetGFSAnalysisFromFTP.csh "'''+self.WorkDir+'''"
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
    script = $origin/applications/UngribExternalAnalysis.csh "'''+self.WorkDir+'''"
'''+ungribtask.job()+ungribtask.directives()+'''

  [[LinkExternalAnalyses]]
    inherit = '''+self.groupName+'''
  [[ExternalAnalysisReady]]
    inherit = '''+self.groupName+''', BACKGROUND''']

    for name, m in meshes.items():
      linkArgs = '"'+self['ExternalAnalysesDir'+name]+'"'
      linkArgs += ' "'+str(self['externalanalyses__directory'+name])+'"'
      linkArgs += ' "'+self['externalanalyses__filePrefix'+name]+'"'

      self._tasks += [
'''
  [[LinkExternalAnalysis-'''+m.name+''']]
    inherit = LinkExternalAnalyses, SingleBatch
    script = $origin/applications/LinkExternalAnalysis.csh '''+linkArgs+'''
    [[[job]]]
      execution time limit = PT30S
      execution retry delays = 1*PT30S''']

    #########
    # outputs
    #########
    self.outputs = {}
    for name, m in meshes.items():
      self.outputs[name] = [{
        'directory': self['ExternalAnalysesDir'+name],
        'prefix': self['externalanalyses__filePrefix'+name],
      }]
