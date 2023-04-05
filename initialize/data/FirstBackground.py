#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.applications.Forecast import Forecast
from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Task import TaskLookup

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.StateEnsemble import StateEnsemble

from initialize.framework.HPC import HPC
from initialize.framework.Workflow import Workflow

class FirstBackground(Component):
  defaults = 'scenarios/defaults/firstbackground.yaml'

  variablesWithDefaults = {
    ## resource:
    # used to select from among available options (e.g., see defaults)
    # must be in quotes
    # e.g., "PANDAC.GFS"
    'resource': ['ForecastFromAnalysis', str,
      ['ForecastFromAnalysis', 'PANDAC.GFS', 'PANDAC.LaggedGEFS']],
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
    meshes:dict,
    members:Members,
    workflow:Workflow,
    ea:ExternalAnalyses,
    coldIC:StateEnsemble,
    fc:Forecast,
  ):
    super().__init__(config)

    assert fc.mesh == coldIC.mesh(), 'coldIC must be on same mesh as forecast'

    ###################
    # derived variables
    ###################
    resourceName = 'firstbackground__resource'
    resource = self['resource']
    self._set(resourceName, resource)
    self._cshVars.append(resourceName)

    # check for valid members.n
    maxMembers = self.extractResourceOrDie(('resources', resource, meshes['Outer'].name), 'maxMembers', int)
    assert members.n > 0 and members.n <= maxMembers, (
      self._msg('invalid members.n => '+str(members.n)))

    for meshTyp, mesh in meshes.items():
      for (key, typ) in [
        ['directory', str],
        ['filePrefix', str],
        ['memberFormat', str],
        ['PrepareFirstBackground', str],
      ]:
        value = self.extractResource(('resources', resource, mesh.name), key, typ)
        if key == 'PrepareFirstBackground':
          # push back cylc mini-workflow
          variable = key+meshTyp
        else:
          # auto-generated csh variables
          if key == 'directory' and isinstance(value, str):
            value = value.replace('{{FirstCycleDate}}', workflow['FirstCycleDate'])

          variable = 'firstbackground__'+key+meshTyp
          self._cshVars.append(variable)

        self._set(variable, value)

    ########################
    # tasks and dependencies
    ########################
    if workflow['first cycle point'] == workflow['restart cycle point']:

      # cold-start, only run R1 cycle, controlled in self.defaults
      base = 'ColdForecast'
      if base in self['PrepareFirstBackgroundOuter']:
        # TODO: base task has no inheritance, would only work with 2 separate classes
        #   consider refactoring; could move Cold* to FirstBackground and make that ctor
        #   take a Forecast instance as an arg (swap dependence)
        job = fc.job
        task = TaskLookup[hpc.system](job)
        self._tasks += ['''
  [['''+base+''']]
    inherit = '''+self.tf.execute+'''
'''+task.job()+task.directives()]

        for mm in range(1, fc.NN+1, 1):
          # fcArgs explanation
          # IAU (False) cannot be used until 1 cycle after DA analysis
          # DACycling (False), IC ~is not~ a DA analysis for which re-coupling is required
          # DeleteZerothForecast (True), not used anywhere else in the workflow
          # updateSea (False) is not needed since the IC is already an external analysis
          args = [
            1,
            fc['lengthHR'],
            fc['outIntervalHR'],
            False,
            fc.mesh.name,
            False,
            True,
            False,
            fc.workDir+'/{{thisCycleDate}}'+fc.memFmt.format(mm),
            coldIC[0].directory(),
            coldIC[0].prefix(),
          ]
          fcArgs = ' '.join(['"'+str(a)+'"' for a in args])

        self._tasks += ['''
  [['''+base+str(mm)+''']]
    inherit = '''+base+''', BATCH
    script = $origin/bin/Forecast.csh '''+fcArgs]

      # link (prepares outer and inner meshes as needed)
      base = 'LinkWarmStartBackgrounds'
      if base in self['PrepareFirstBackgroundOuter']:
        self._tasks += ['''
  [['''+base+''']]
    inherit = '''+self.tf.execute+''', SingleBatch
    script = $origin/bin/'''+base+'''.csh
    [[[job]]]
      # give longer for higher resolution and more EDA members
      # TODO: set time limit based on outerMesh AND (number of members OR
      #       independent task for each member)
      execution time limit = PT10M
      execution retry delays = 1*PT5S''']

      # open graph
      self._dependencies += ['''
    [[[R1]]]
      graph = """''']

      self._dependencies += ['''
        # prepare first DA background state
        '''+ea['PrepareExternalAnalysisOuter']+''' => '''+self['PrepareFirstBackgroundOuter']+'''

        # prepare analyses (init) files (for dual-mesh Variational) for reading to
        # static and input stream in all cycles for inner and ensemble geometries
        '''+ea['PrepareExternalAnalysisInner']+'''
        '''+ea['PrepareExternalAnalysisEnsemble']]

      self._dependencies = self.tf.updateDependencies(self._dependencies)

      # close graph
      self._dependencies += ['''
      """''']

    self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)
