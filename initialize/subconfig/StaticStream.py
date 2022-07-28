#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class StaticStream(SubConfig):
  baseKey = 'staticstream'
  defaults = 'scenarios/base/staticstream.yaml'

  optionalVariables = {
    ## resource:
    # used to select from among available options (e.g., see defaults)
    # must be in quotes
    # e.g., "PANDAC.LaggedGEFS"
    'resource': str,
  }

  def __init__(self, config, meshes, members, FirstCycleDate):
    super().__init__(config)

    csh = []
    cylc = []

    ###################
    # derived variables
    ###################
    resourceName = 'staticstream__resource'
    resource = self.get('resource')
    self._set(resourceName, resource)
    csh.append(resourceName)

    for name, m in meshes.items():
      mesh = m.name
      nCells = str(m.nCells)

      for key in ['directory', 'filePrefix', 'memberFormat']:
        value = self.extractResource(resource, mesh, key)
        if key == 'directory' and isinstance(value, str):
          value = value.replace('{{FirstCycleDate}}', FirstCycleDate)

        if key == 'filePrefix' and isinstance(value, str):
          value = value.replace('{{nCells}}', nCells)

        # auto-generated csh variables
        variable = 'staticstream__'+key+name
        self._set(variable, value)
        csh.append(variable)

    # check for uniform static stream used across members (maxMembers is None) or valid members.n
    maxMembers = self.extractResource(resource, meshes['Outer'].name, 'maxMembers')
    if maxMembers is not None:
      assert (members.n <= int(maxMembers)), (
        self.logPrefix+'invalid members.n => '+str(members.n))

    ###############################
    # export for use outside python
    ###############################
    self.exportVars(csh, cylc)
