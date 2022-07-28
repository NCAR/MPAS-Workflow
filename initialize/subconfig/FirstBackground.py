#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class FirstBackground(SubConfig):
  baseKey = 'firstbackground'
  defaults = 'scenarios/base/firstbackground.yaml'

  requiredVariables = {
    ## resource:
    # used to select from among available options (e.g., see defaults)
    # must be in quotes
    # e.g., "ForecastFromAnalysis", "PANDAC.GFS", "PANDAC.LaggedGEFS"
    'resource': str,
  }

  @staticmethod
  def extractResource(config, resource, mesh, key):
    value = config.get('.'.join([resource, mesh, key]))
    if value is None:
      value = config.get('.'.join([resource, 'common', key]))

    if value is None:
      value = config.get('.'.join(['defaults', key]))

    return value

  def __init__(self, config, meshes, members):
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
    maxMembers = self.extractResource(config, resource, meshes['Outer'].name, 'maxMembers')
    assert members.n > 0 and members.n <= maxMembers, (
      self.logPrefix+'invalid members.n => '+str(members.n))

    for name, m in meshes.items():
      mesh = m.name
      nCells = str(m.nCells)

      for key in [
        'directory',
        'filePrefix',
        'memberFormat',
        'PrepareFirstBackground',
      ]:
        value = self.extractResource(config, resource, mesh, key)
        if key == 'PrepareFirstBackground':
          # push back cylc mini-workflow
          variable = key+name
          cylc.append(variable)
        else:
          # auto-generated csh variables
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
