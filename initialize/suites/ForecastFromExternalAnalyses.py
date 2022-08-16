#!/usr/bin/env python3

from initialize.Config import Config
from initialize.Suite import Suite
from initialize.components.Build import Build
from initialize.components.Experiment import Experiment
from initialize.components.ExternalAnalyses import ExternalAnalyses
from initialize.components.HPC import HPC
from initialize.components.Members import Members
from initialize.components.Model import Model
from initialize.components.Naming import Naming
from initialize.components.Observations import Observations
from initialize.components.StaticStream import StaticStream
from initialize.components.Workflow import Workflow

# applications
from initialize.components.InitIC import InitIC
from initialize.components.ExtendedForecast import ExtendedForecast
from initialize.components.Forecast import Forecast
from initialize.components.HofX import HofX
from initialize.components.VerifyModel import VerifyModel
from initialize.components.VerifyObs import VerifyObs

class ForecastFromExternalAnalyses(Suite):
  def __init__(self, conf:Config):
    c = {}
    c['hpc'] = HPC(conf)
    c['workflow'] = Workflow(conf)

    c['model'] = Model(conf)
    meshes = c['model'].getMeshes()

    c['build'] = Build(conf, c['model'])
    c['obs'] = Observations(conf, c['hpc'])
    c['members'] = Members(conf)

    c['ea'] = ExternalAnalyses(conf, c['hpc'], meshes)
    c['ic'] = InitIC(conf, c['hpc'], meshes, c['ea'])
    c['hofx'] = HofX(conf, c['hpc'], meshes, c['model'])
    c['fc'] = Forecast(conf, c['hpc'], meshes['Outer'], c['members'], c['workflow'],
                c['ea'].outputs['Outer'], 
                c['ea'].outputs['Outer'])
    c['extfc'] = ExtendedForecast(conf, c['hpc'], c['members'], c['fc'],
                c['ea'].outputs['Outer'],
                c['ea'].outputs['Outer'][0],
                c['ea'].outputs['Outer'])

    #if conf.has('verifymodel'): # TODO: make verifymodel optional
    c['vmodel'] = VerifyModel(conf, c['hpc'], meshes['Outer'], c['members'])

    #if conf.has('verifyobs'): # TODO: make verifyobs optional
    c['vobs'] = VerifyObs(conf, c['hpc'], c['members'])

    c['exp'] = Experiment(conf, c['hpc'])
    c['ss'] = StaticStream(conf, meshes, c['members'], c['workflow']['FirstCycleDate'], c['ea'], c['exp'])

    c['naming'] = Naming(conf, c['exp'])

    for c_ in c.values():
      c_.export()
