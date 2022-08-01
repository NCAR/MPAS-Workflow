#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.ExternalAnalyses import ExternalAnalyses
from initialize.subconfig.Job import Job
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

    job = Job(conf)
    workflow = Workflow(conf)

    model = Model(conf)
    meshes = model.getMeshes()
    obs = Observations(conf)
    members = Members(conf)

    ea = ExternalAnalyses(conf, meshes)
    ss = StaticStream(conf, meshes, members, workflow['FirstCycleDate'])

    ic = InitIC(conf, meshes)
    hofx = HofX(conf, meshes, model)
    fc = Forecast(conf, meshes['Outer'], members, workflow)
    extfc = ExtendedForecast(conf, members, fc,)
    vmodel = VerifyModel(conf, meshes['Outer'], members)
    vobs = VerifyObs(conf, members)
