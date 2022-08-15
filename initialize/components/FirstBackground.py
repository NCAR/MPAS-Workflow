#!/usr/bin/env python3

from initialize.Component import Component

class FirstBackground(Component):
  defaults = 'scenarios/defaults/firstbackground.yaml'

  requiredVariables = {
    ## resource:
    # used to select from among available options (e.g., see defaults)
    # must be in quotes
    # e.g., "ForecastFromAnalysis", "PANDAC.GFS", "PANDAC.LaggedGEFS"
    'resource': str,
  }

  def __init__(self, config, meshes, members, FirstCycleDate):
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

    for name, m in meshes.items():
      mesh = m.name
      nCells = str(m.nCells)

      for (key, t) in [
        ['directory', str],
        ['filePrefix', str],
        ['memberFormat', str],
        ['PrepareFirstBackground', str],
      ]:
        value = self.extractResource(('resources', resource, mesh), key, t)
        if key == 'PrepareFirstBackground':
          # push back cylc mini-workflow
          variable = key+name
          self._cylcVars.append(variable)
        else:
          # auto-generated csh variables
          if key == 'directory' and isinstance(value, str):
            value = value.replace('{{FirstCycleDate}}', FirstCycleDate)

          variable = 'firstbackground__'+key+name
          self._cshVars.append(variable)

        self._set(variable, value)

    ########################
    # tasks and dependencies
    ########################
    self.groupName = self.__class__.__name__
    self._tasks = ['''
  [['''+self.groupName+''']]
  [[LinkWarmStartBackgrounds]]
    inherit = '''+self.groupName+''', SingleBatch
    script = $origin/applications/LinkWarmStartBackgrounds.csh
    [[[job]]]
      # give longer for higher resolution and more EDA members
      # TODO: set time limit based on outerMesh AND (number of members OR
      #       independent task for each member)
      execution time limit = PT10M
      execution retry delays = 1*PT5S''']
