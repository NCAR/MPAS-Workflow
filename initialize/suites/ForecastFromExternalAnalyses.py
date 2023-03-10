#!/usr/bin/env python3

from initialize.applications.InitIC import InitIC
from initialize.applications.ExtendedForecast import ExtendedForecast
from initialize.applications.Forecast import Forecast
from initialize.applications.Members import Members

from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.Model import Model
from initialize.data.Observations import Observations
from initialize.data.StaticStream import StaticStream

from initialize.framework.Build import Build
from initialize.framework.Experiment import Experiment
from initialize.framework.HPC import HPC
from initialize.framework.Naming import Naming
from initialize.framework.Workflow import Workflow

#from initialize.post.Benchmark import Benchmark

from initialize.suites.Suite import Suite

class ForecastFromExternalAnalyses(Suite):
  def __init__(self, conf:Config):
    super().__init__()

    c = {}
    c['hpc'] = HPC(conf)
    c['workflow'] = Workflow(conf)

    c['model'] = Model(conf)
    meshes = c['model'].getMeshes()

    c['build'] = Build(conf, c['model'])
    c['obs'] = Observations(conf, c['hpc'])
    c['members'] = Members(conf)

    c['externalanalyses'] = ExternalAnalyses(conf, c['hpc'], meshes)
    c['ic'] = InitIC(conf, c['hpc'], meshes, c['externalanalyses'])

    # Forecast object is only used to initialize parts of ExtendedForecast
    c['fc'] = Forecast(conf, c['hpc'], meshes['Outer'], c['members'], c['model'], c['obs'],
                c['workflow'], c['externalanalyses'],
                c['externalanalyses'].outputs['state']['Outer'])
    c['extendedforecast'] = ExtendedForecast(conf, c['hpc'], c['members'], c['fc'],
                c['externalanalyses'], c['obs'],
                c['externalanalyses'].outputs['state']['Outer'], 'external')

    c['exp'] = Experiment(conf, c['hpc'])
    c['ss'] = StaticStream(conf, meshes, c['members'], c['workflow']['FirstCycleDate'], c['externalanalyses'], c['exp'])

    c['naming'] = Naming(conf, c['exp'])

    for k, c_ in c.items():
      if k in ['obs', 'ic', 'externalanalyses']:
        c_.export(c['extendedforecast']['extLengths'])
      elif k in ['extendedforecast']:
        c_.export(c['externalanalyses']['PrepareExternalAnalysisOuter'])
      elif k in ['fc']:
        continue
      else:
        c_.export()
