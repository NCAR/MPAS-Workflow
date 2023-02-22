#!/usr/bin/env python3

from initialize.Component import Component

from initialize.components.Experiment import Experiment
from initialize.components.ExternalAnalyses import ExternalAnalyses
#from initialize.components.Members import Members
from initialize.components.Observations import Observations

# applications
from initialize.components.Benchmark import Benchmark
from initialize.components.ExtendedForecast import ExtendedForecast
from initialize.components.Forecast import Forecast
#from initialize.components.HofX import HofX
from initialize.components.VerifyModel import VerifyModel
from initialize.components.VerifyObs import VerifyObs

from initialize.components.RTPP import RTPP
from initialize.components.DA import DA
from initialize.components.Variational import ABEI

class Naming(Component):
  def __init__(self, config, exp:Experiment, bench=None):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    namedComponents = [
      DA,
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
