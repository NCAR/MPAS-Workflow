#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

import datetime as dt
import tools.dateFormats as dtf

from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses

from initialize.framework.Experiment import Experiment

class InvariantStream(Component):
  defaults = 'scenarios/defaults/invariantstream.yaml'

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

    for meshTyp, m in meshes.items():
      mesh = m.name
      nCells = str(m.nCells)
      meshRatio = str(m.meshRatio)

      for key in ['directory', 'filePrefix']:
        value = self.extractResource(('resources', resource, mesh), key, str)
        if key == 'directory':
          value = value.replace('{{FirstCycleDate}}', FirstCycleDate)

        if key == 'filePrefix':
          value = value.replace('{{nCells}}', nCells)
          value = value.replace('{{meshRatio}}', meshRatio)

        # auto-generated csh variables
        variable = key+meshTyp
        self._set(variable, value)

      #############################
      # invariant stream file settings
      #############################
      dirName = 'InvariantFieldsDir'+meshTyp
      self._set(dirName, self['directory'+meshTyp].replace(
          '{{ExternalAnalysesDir}}',
          exp['directory']+'/'+ea['ExternalAnalysesDir'+meshTyp].replace(
            '/{{thisValidDate}}', '')
        )
      )
      self._cshVars.append(dirName)

      n = 'InvariantFieldsFile'+meshTyp
      self._set(n, self['filePrefix'+meshTyp]+'.'+FirstFileDate+'.nc')
      self._cshVars.append(n)

    invariantMemFmt = self.extractResource(('resources', resource, meshes['Outer'].name), 'memberFormat', str)
    self._set('invariantMemFmt', invariantMemFmt)
    self._cshVars.append('invariantMemFmt')

    # check for uniform invariant stream used across members (maxMembers is None) or valid members.n
    maxMembers = self.extractResource(('resources', resource, meshes['Outer'].name), 'maxMembers', int)
    if maxMembers is not None:
      assert (members.n <= int(maxMembers)), (
        self._msg('invalid members.n => '+str(members.n)))
