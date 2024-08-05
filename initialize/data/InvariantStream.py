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

      for key in ['InvariantDirectory', 'InvariantFilePrefix', 'InitDirectory', 'InitFilePrefix']:
        value = self.extractResource(('resources', resource, mesh), key, str)

        if key == 'InitDirectory':
          value = value.replace('{{FirstCycleDate}}', FirstCycleDate)

        if key == 'InvariantFilePrefix' or key == 'InitFilePrefix':
          value = value.replace('{{nCells}}', nCells)
          value = value.replace('{{meshRatio}}', meshRatio)

        # auto-generated csh variables
        variable = key+meshTyp
        self._set(variable, value)

      #############################
      # invariant stream file settings
      #############################
      dirName = 'InvariantFieldsDir'+meshTyp
      self._set(dirName, self['InvariantDirectory'+meshTyp])
      self._cshVars.append(dirName)

      fileName = 'InvariantFieldsFile'+meshTyp
      self._set(fileName, self['InvariantFilePrefix'+meshTyp]+'.nc')
      self._cshVars.append(fileName)

      initDirName = 'InitFieldsDir'+meshTyp
      self._set(initDirName, self['InitDirectory'+meshTyp].replace(
          '{{ExternalAnalysesDir}}',exp['directory']+'/'+ea['ExternalAnalysesDir'+meshTyp].replace(
            '/{{thisValidDate}}', '')
          )
      )
      self._cshVars.append(initDirName)

      initFileName = 'InitFieldsFile'+meshTyp
      self._set(initFileName, self['InitFilePrefix'+meshTyp]+'.'+FirstFileDate+'.nc')
      self._cshVars.append(initFileName)
