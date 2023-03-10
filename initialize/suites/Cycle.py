#!/usr/bin/env python3

from initialize.applications.DA import DA
from initialize.applications.ExtendedForecast import ExtendedForecast
from initialize.applications.Forecast import Forecast
from initialize.applications.InitIC import InitIC
from initialize.applications.Members import Members

from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.FirstBackground import FirstBackground
from initialize.data.Model import Model
from initialize.data.Observations import Observations
from initialize.data.StaticStream import StaticStream

from initialize.framework.Build import Build
from initialize.framework.Experiment import Experiment
from initialize.framework.HPC import HPC
from initialize.framework.Naming import Naming
from initialize.framework.Workflow import Workflow

from initialize.post.Benchmark import Benchmark

from initialize.suites.Suite import Suite


class Cycle(Suite):
  def __init__(self, conf:Config):
    super().__init__()

    c = {}
    c['hpc'] = HPC(conf)
    c['workflow'] = Workflow(conf)

    c['model'] = Model(conf)
    c['build'] = Build(conf, c['model'])
    meshes = c['model'].getMeshes()
    c['obs'] = Observations(conf, c['hpc'])
    c['members'] = Members(conf)

    c['externalanalyses'] = ExternalAnalyses(conf, c['hpc'], meshes)
    c['ic'] = InitIC(conf, c['hpc'], meshes, c['externalanalyses'])
    c['da'] = DA(conf, c['hpc'], c['obs'], meshes, c['model'], c['members'], c['workflow'])
    c['fc'] = Forecast(conf, c['hpc'], meshes['Outer'], c['members'], c['model'], c['obs'],
                c['workflow'], c['externalanalyses'], c['da'].outputs['state']['members'])
    c['fb'] = FirstBackground(conf, c['hpc'], meshes, c['members'], c['workflow'],
                c['externalanalyses'],
                c['externalanalyses'].outputs['state']['Outer'], c['fc'])
    c['extendedforecast'] = ExtendedForecast(conf, c['hpc'], c['members'], c['fc'],
                c['externalanalyses'], c['obs'],
                c['da'].outputs['state']['members'], 'internal')

    #if conf.has('benchmark'): # TODO: make benchmark optional,
    # and depend on whether verifyobs/verifymodel are selected
    c['bench'] = Benchmark(conf, c['hpc'])

    c['exp'] = Experiment(conf, c['hpc'], meshes, c['da'].var, c['members'], c['da'].rtpp)
    c['ss'] = StaticStream(conf, meshes, c['members'], c['workflow']['FirstCycleDate'], c['externalanalyses'], c['exp'])

    c['naming'] = Naming(conf, c['exp'], c['bench'])

    for k, c_ in c.items():
      if k in ['obs', 'ic', 'externalanalyses']:
        c_.export(c['extendedforecast']['extLengths'])
      elif k in ['fc']:
        c_.export(c['da'].TM.finished, c['da'].TM.clean, c['da'].meanBGDir)
      elif k in ['da']:
        c_.export(c['fc'].previousForecast, c['extendedforecast'])
      elif k in ['extendedforecast']:
        c_.export(c['da'].TM.finished, activateEnsemble=False)
      else:
        c_.export()
