#!/usr/bin/env python3

from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses

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
    meshes:dict,
    members:Members,
    workflow:Workflow,
    ea:ExternalAnalyses,
  ):
    super().__init__(config)

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

    # link (prepares outer and inner meshes as needed)
    base = 'LinkWarmStartBackgrounds'
    if base in self['PrepareFirstBackgroundOuter']:
      self._tasks += ['''
  [['''+self.base+''']]
  [['''+base+''']]
    inherit = '''+self.base+''', SingleBatch
    script = $origin/bin/'''+base+'''.csh
    [[[job]]]
      # give longer for higher resolution and more EDA members
      # TODO: set time limit based on outerMesh AND (number of members OR
      #       independent task for each member)
      execution time limit = PT10M
      execution retry delays = 1*PT5S''']

    if workflow['first cycle point'] == workflow['restart cycle point']:
      self._dependencies += ['''
    [[[R1]]]
      graph = """
        # prepare first DA background state
        '''+ea['PrepareExternalAnalysisOuter']+''' => '''+self['PrepareFirstBackgroundOuter']+'''

        # prepare analyses (init) files (for dual-mesh Variational) for reading to
        # static and input stream in all cycles for inner and ensemble geometries
        '''+ea['PrepareExternalAnalysisInner']+'''
        '''+ea['PrepareExternalAnalysisEnsemble']+'''
      """''']
