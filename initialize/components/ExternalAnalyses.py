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

  def __init__(self, config, hpc, meshes):
    super().__init__(config)
    self.meshes = meshes

    ###################
    # derived variables
    ###################
    resourceName = 'externalanalyses__resource'
    resource = self['resource']
    self._set(resourceName, resource)
    self._cshVars.append(resourceName)

    # WorkDir is where external analysis files are linked/downloaded, e.g., in grib format
    self.WorkDir = self.workDir+'/'+resource+'/{{thisValidDate}}'

    for typ, m in meshes.items():
      mesh = m.name
      nCells = str(m.nCells)
      # 'ExternalAnalysesDir'+typ is where external analyses converted to MPAS meshes are
      # created and/or stored
      self._set('ExternalAnalysesDir'+typ, self.workDir+'/'+mesh+'/{{thisValidDate}}')
      self._cshVars.append('ExternalAnalysesDir'+typ)

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
          variable = key+typ
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
          variable = 'externalanalyses__'+key+typ
          if key in ['Vtable','UngribPrefix']:
            if typ == 'Outer':
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
    self.__getRetry = self.extractResourceOrDie(('resources', resource), 'job.GetAnalysisFrom.retry', str)

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
    self.__ungribtask = TaskFactory[hpc.system](ungribjob)

    self.groupName = self.__class__.__name__

    #########
    # outputs
    #########
    self.outputs = {}
    for typ, m in meshes.items():
      self.outputs[typ] = [{
        'directory': self['ExternalAnalysesDir'+typ],
        'prefix': self['externalanalyses__filePrefix'+typ],
      }]

  def export(self, components):
    if 'extendedforecast' in components:
      dtOffsets=components['extendedforecast']['extLengths']
    else:
      dtOffsets=[0]

    meshTypes = []
    meshNames = []
    for typ, m in self.meshes.items():
      if m.name not in meshNames:
        meshNames.append(m.name)
        meshTypes.append(typ)

    self._tasks = [
'''## Analyses generated outside MPAS-Workflow
  [['''+self.groupName+''']]
  [[GetGDASAnalysisFromFTP]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/GetGDASAnalysisFromFTP.csh
    [[[job]]]
      execution time limit = PT45M
      execution retry delays = '''+self.__getRetry]

    for dt in dtOffsets:
      dtStr = str(dt)
      dt_work_Args = '"'+dtStr+'" "'+self.WorkDir+'"'
      self._tasks += ['''
  [[GetGFSAnalysisFromRDA-'''+dtStr+'''hr]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/GetGFSAnalysisFromRDA.csh '''+dt_work_Args+'''
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = '''+self.__getRetry+'''
  [[GetGFSAnalysisFromFTP-'''+dtStr+'''hr]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/GetGFSAnalysisFromFTP.csh '''+dt_work_Args+'''
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = '''+self.__getRetry+'''
  [[UngribExternalAnalysis-'''+dtStr+'''hr]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/UngribExternalAnalysis.csh '''+dt_work_Args+'''
'''+self.__ungribtask.job()+self.__ungribtask.directives()+'''
  [[ExternalAnalysisReady-'''+dtStr+'''hr]]
    inherit = '''+self.groupName]

      for typ, name in zip(meshTypes, meshNames):
        args = [
          dt,
          self['ExternalAnalysesDir'+typ],
          self['externalanalyses__directory'+typ],
          self['externalanalyses__filePrefix'+typ],
        ]
        linkArgs = ' '.join(['"'+str(a)+'"' for a in args])
        self._tasks += ['''
  [[LinkExternalAnalysis-'''+name+'''-'''+dtStr+'''hr]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/LinkExternalAnalysis.csh '''+linkArgs+'''
    [[[job]]]
      execution time limit = PT30S
      execution retry delays = 1*PT30S''']

    self._tasks += ['''
  [[GetGFSAnalysisFromRDA]]
    inherit = GetGFSAnalysisFromRDA-0hr
  [[GetGFSAnalysisFromFTP]]
    inherit = GetGFSAnalysisFromFTP-0hr
  [[UngribExternalAnalysis]]
    inherit = UngribExternalAnalysis-0hr
  [[ExternalAnalysisReady]]
    inherit = '''+self.groupName]

    for typ, name in zip(meshTypes, meshNames):
      self._tasks += ['''
  [[LinkExternalAnalysis-'''+name+''']]
    inherit = LinkExternalAnalysis-'''+name+'''-0hr''']

    super().export(components)
