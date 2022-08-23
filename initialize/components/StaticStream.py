#!/usr/bin/env python3

import datetime as dt
import tools.dateFormats as dtf

from initialize.Component import Component

class StaticStream(Component):
  defaults = 'scenarios/defaults/staticstream.yaml'

  optionalVariables = {
    ## resource:
    # used to select from among available options (e.g., see defaults)
    # must be in quotes
    # e.g., "PANDAC.LaggedGEFS"
    'resource': str,
  }

  def __init__(self, config, meshes, members, FirstCycleDate, ea, exp):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    resource = self['resource']

    FirstFileDate = dt.datetime.strptime(FirstCycleDate, dtf.cycleFmt).strftime(dtf.MPASFileFmt)

    for name, m in meshes.items():
      mesh = m.name
      nCells = str(m.nCells)

      for key in ['directory', 'filePrefix']:
        value = self.extractResource(('resources', resource, mesh), key, str)
        if key == 'directory':
          value = value.replace('{{FirstCycleDate}}', FirstCycleDate)

        if key == 'filePrefix':
          value = value.replace('{{nCells}}', nCells)

        # auto-generated csh variables
        variable = key+name
        self._set(variable, value)

      #############################
      # static stream file settings
      #############################
      dirName = 'StaticFieldsDir'+name
      self._set(dirName, self['directory'+name].replace(
          '{{ExternalAnalysesDir}}',
          exp['directory']+'/'+ea['ExternalAnalysesDir'+name].replace(
            '/{{thisValidDate}}', '')
        )
      )
      self._cshVars.append(dirName)

      n = 'StaticFieldsFile'+name
      self._set(n, self['filePrefix'+name]+'.'+FirstFileDate+'.nc')
      self._cshVars.append(n)

    staticMemFmt = self.extractResource(('resources', resource, meshes['Outer'].name), 'memberFormat', str)
    self._set('staticMemFmt', staticMemFmt)
    self._cshVars.append('staticMemFmt')

    # check for uniform static stream used across members (maxMembers is None) or valid members.n
    maxMembers = self.extractResource(('resources', resource, meshes['Outer'].name), 'maxMembers', int)
    if maxMembers is not None:
      assert (members.n <= int(maxMembers)), (
        self._msg('invalid members.n => '+str(members.n)))