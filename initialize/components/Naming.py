#!/usr/bin/env python3

from initialize.Component import Component

from initialize.components.ExternalAnalyses import ExternalAnalyses
#from initialize.components.Members import Members
from initialize.components.Observations import Observations

# applications
#from initialize.components.Benchmark import Benchmark
from initialize.components.ExtendedForecast import ExtendedForecast
from initialize.components.Forecast import Forecast
#from initialize.components.HofX import HofX
from initialize.components.VerifyModel import VerifyModel
from initialize.components.VerifyObs import VerifyObs

from initialize.components.RTPP import RTPP
from initialize.components.Variational import Variational
from initialize.components.Variational import ABEI

class Naming(Component):
  def __init__(self, config, experiment):#, namedComponents):
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
    self.directories = {}
    for c in namedComponents:
      v = c.__name__+'WorkDir'
      value = experiment['ExperimentDirectory']+'/'+c.workDir
      self._set(v, value)
      self.directories[v] = value

    self._cshVars = list(self._vtable.keys())
