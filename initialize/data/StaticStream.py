#!/usr/bin/env python3

import datetime as dt
import tools.dateFormats as dtf

from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses

from initialize.framework.Experiment import Experiment

class StaticStream(Component):
  defaults = 'scenarios/defaults/staticstream.yaml'

  optionalVariables = {
    ## resource:
    # used to select from among available options (e.g., see defaults)
    # must be in quotes
    # e.g., "PANDAC.LaggedGEFS"
    'resource': str,
  }

  def __init__(self,
    config:Config,
    meshes:dict,
    members:Members,
    FirstCycleDate:str,
    ea:ExternalAnalyses,
    exp:Experiment,
  ):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    resource = self['resource']

    FirstFileDate = dt.datetime.strptime(FirstCycleDate, dtf.cycleFmt).strftime(dtf.MPASFileFmt)

    for typ, m in meshes.items():
      mesh = m.name
      nCells = str(m.nCells)

      for key in ['directory', 'filePrefix']:
        value = self.extractResource(('resources', resource, mesh), key, str)
        if key == 'directory':
          value = value.replace('{{FirstCycleDate}}', FirstCycleDate)

        if key == 'filePrefix':
          value = value.replace('{{nCells}}', nCells)

        # auto-generated csh variables
        variable = key+typ
        self._set(variable, value)

      #############################
      # static stream file settings
      #############################
      dirName = 'StaticFieldsDir'+typ
      self._set(dirName, self['directory'+typ].replace(
          '{{ExternalAnalysesDir}}',
          exp['directory']+'/'+ea['ExternalAnalysesDir'+typ].replace(
            '/{{thisValidDate}}', '')
        )
      )
      self._cshVars.append(dirName)

      n = 'StaticFieldsFile'+typ
      self._set(n, self['filePrefix'+typ]+'.'+FirstFileDate+'.nc')
      self._cshVars.append(n)

    staticMemFmt = self.extractResource(('resources', resource, meshes['Outer'].name), 'memberFormat', str)
    self._set('staticMemFmt', staticMemFmt)
    self._cshVars.append('staticMemFmt')

    # check for uniform static stream used across members (maxMembers is None) or valid members.n
    maxMembers = self.extractResource(('resources', resource, meshes['Outer'].name), 'maxMembers', int)
    if maxMembers is not None:
      assert (members.n <= int(maxMembers)), (
        self._msg('invalid members.n => '+str(members.n)))
