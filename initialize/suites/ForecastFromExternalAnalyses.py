#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.ExternalAnalyses import ExternalAnalyses
from initialize.subconfig.HPC import HPC
from initialize.subconfig.Members import Members
from initialize.subconfig.Model import Model
from initialize.subconfig.Observations import Observations
from initialize.subconfig.StaticStream import StaticStream
from initialize.subconfig.Workflow import Workflow

# applications
from initialize.subconfig.InitIC import InitIC
from initialize.subconfig.ExtendedForecast import ExtendedForecast
from initialize.subconfig.Forecast import Forecast
from initialize.subconfig.HofX import HofX
from initialize.subconfig.VerifyModel import VerifyModel
from initialize.subconfig.VerifyObs import VerifyObs

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
