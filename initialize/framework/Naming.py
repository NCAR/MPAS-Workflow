#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.applications.ExtendedForecast import ExtendedForecast
from initialize.applications.Forecast import Forecast
from initialize.applications.RTPP import RTPP
from initialize.applications.Variational import Variational, ABEI

from initialize.config.Component import Component
from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.Observations import Observations

from initialize.framework.Experiment import Experiment

from initialize.post.Benchmark import Benchmark
from initialize.post.VerifyModel import VerifyModel
from initialize.post.VerifyObs import VerifyObs

class Naming(Component):
  def __init__(self, config:Config, exp:Experiment, bench:Benchmark=None):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    namedComponents = [
      Variational,
      RTPP,
      ABEI,
      Forecast,
      ExtendedForecast,
      VerifyObs,
      #VerifyModel, #only need VerifyObs, because they are the same
      Observations,
      ExternalAnalyses,
    ]

    # experiment directories
    self.directories = {}
    for c in namedComponents:
      v = c.__name__+'WorkDir'
      value = exp['ExperimentDirectory']+'/'+c.workDir
      self._set(v, value)
      self.directories[v] = value

    # benchmark directories
    for v, value in self.directories.items():
      if bench is None or bench['directory'] is None:
        benchDir = exp['ExperimentDirectory']
      else:
        benchDir = bench['directory']
      self._set('Benchmark'+v,
        value.replace(exp['ExperimentDirectory'], benchDir))

    # cross-application prefixes and directories
    self._set('RSTFilePrefix', 'restart')
    self._set('ICFilePrefix', 'mpasin')
    self._set('FCFilePrefix', 'mpasout')
    self._set('DIAGFilePrefix', 'diag')
    self._set('ANFilePrefix', 'an')
    self._set('BGFilePrefix', 'bg')
    self._set('forecastSubDir', 'fc')
    self._set('analysisSubDir', 'an')
    self._set('backgroundSubDir', 'bg')
    self._set('OrigFileSuffix', '_orig')

    self._cshVars = list(self._vtable.keys())
