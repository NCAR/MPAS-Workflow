#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.components.ExternalAnalyses import ExternalAnalyses
from initialize.components.HPC import HPC
from initialize.components.Members import Members
from initialize.components.Model import Model
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
  ExpConfigType = 'base'
  def __init__(self, scenario):
    conf = scenario.getConfig()

    hpc = HPC(conf)
    workflow = Workflow(conf)

    model = Model(conf)
    meshes = model.getMeshes()
    obs = Observations(conf, hpc)
    members = Members(conf)

    ea = ExternalAnalyses(conf, hpc, meshes)
    ss = StaticStream(conf, meshes, members, workflow['FirstCycleDate'])

    ic = InitIC(conf, hpc, meshes)
    hofx = HofX(conf, hpc, meshes, model)
    fc = Forecast(conf, hpc, meshes['Outer'], members, workflow)
    extfc = ExtendedForecast(conf, hpc, members, fc,)
    vmodel = VerifyModel(conf, hpc, meshes['Outer'], members)
    vobs = VerifyObs(conf, hpc, members)
