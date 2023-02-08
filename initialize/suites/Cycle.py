#!/usr/bin/env python3

from initialize.Config import Config
from initialize.Suite import Suite
from initialize.components.Build import Build
from initialize.components.Experiment import Experiment
from initialize.components.ExternalAnalyses import ExternalAnalyses
from initialize.components.FirstBackground import FirstBackground
from initialize.components.HPC import HPC
from initialize.components.Members import Members
from initialize.components.Model import Model
from initialize.components.Naming import Naming
from initialize.components.Observations import Observations
from initialize.components.StaticStream import StaticStream
from initialize.components.Workflow import Workflow

# applications
from initialize.components.Benchmark import Benchmark
from initialize.components.DA import DA
from initialize.components.InitIC import InitIC
from initialize.components.ExtendedForecast import ExtendedForecast
from initialize.components.Forecast import Forecast
from initialize.components.HofX import HofX
from initialize.components.VerifyModel import VerifyModel
from initialize.components.VerifyObs import VerifyObs

class Cycle(Suite):
  def __init__(self, conf:Config):
    c = {}
    c['hpc'] = HPC(conf)
    c['workflow'] = Workflow(conf)

    c['model'] = Model(conf)
    c['build'] = Build(conf, c['model'])
    meshes = c['model'].getMeshes()
    c['obs'] = Observations(conf, c['hpc'])
    c['members'] = Members(conf)

    c['externalanalyses'] = ExternalAnalyses(conf, c['hpc'], meshes)
    c['fb'] = FirstBackground(conf, meshes, c['members'], c['workflow']['FirstCycleDate'])

    c['ic'] = InitIC(conf, c['hpc'], meshes, c['externalanalyses'])
    c['hofx'] = HofX(conf, c['hpc'], meshes, c['model'])
    c['da'] = DA(conf, c['hpc'], c['obs'], meshes, c['model'], c['members'], c['workflow'], c['build'])
    c['fc'] = Forecast(conf, c['hpc'], meshes['Outer'], c['members'], c['workflow'],
                c['externalanalyses'].outputs['Outer'],
                c['da'].outputs['members'])
    c['extendedforecast'] = ExtendedForecast(conf, c['hpc'], c['members'], c['fc'],
                c['externalanalyses'].outputs['Outer'],
                c['da'].outputs['mean'],
                c['da'].outputs['members'])

    #if conf.has('verifymodel'): # TODO: make verifymodel optional
    c['vmodel'] = VerifyModel(conf, c['hpc'], meshes['Outer'], c['members'])

    #if conf.has('verifyobs'): # TODO: make verifyobs optional
    c['vobs'] = VerifyObs(conf, c['hpc'], c['members'])

    #if conf.has('benchmark'): # TODO: make benchmark optional,
    # and depend on whether verifyobs/verifymodel are selected
    c['bench'] = Benchmark(conf, c['hpc'])

    c['exp'] = Experiment(conf, c['hpc'], meshes, c['da'], c['members'])
    c['ss'] = StaticStream(conf, meshes, c['members'], c['workflow']['FirstCycleDate'], c['externalanalyses'], c['exp'])

    c['naming'] = Naming(conf, c['exp'], c['bench'])

    for c_ in c.values():
      c_.export(c)
