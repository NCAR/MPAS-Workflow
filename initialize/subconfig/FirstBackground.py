#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class FirstBackground(SubConfig):
  baseKey = 'firstbackground'
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

    csh = []
    cylc = []

    ###################
    # derived variables
    ###################
    resourceName = 'firstbackground__resource'
    resource = self.get('resource')
    self._set(resourceName, resource)
    csh.append(resourceName)

    # check for valid members.n
    maxMembers = self.extractResourceOrDie(resource, meshes['Outer'].name, 'maxMembers', int)
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
        value = self.extractResource(resource, mesh, key, t)
        if key == 'PrepareFirstBackground':
          # push back cylc mini-workflow
          variable = key+name
          cylc.append(variable)
        else:
          # auto-generated csh variables
          if key == 'directory' and isinstance(value, str):
            value = value.replace('{{FirstCycleDate}}', FirstCycleDate)

          variable = 'firstbackground__'+key+name
          csh.append(variable)

        self._set(variable, value)

    ###############################
    # export for use outside python
    ###############################
    self.exportVars(csh, cylc)

    tasks = [
'''
  [[LinkWarmStartBackgrounds]]
    inherit = BATCH
    script = $origin/applications/LinkWarmStartBackgrounds.csh
    [[[job]]]
      # give longer for higher resolution and more EDA members
      # TODO: set time limit based on outerMesh AND (number of members OR
      #       independent task for each member)
      execution time limit = PT10M
      execution retry delays = 1*PT5S''']

    self.exportTasks(tasks)
