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

class ForecastFromExternalAnalyses(Suite):
  ExpConfigType = 'base'
  appDependentConfigs = ['verifyobs', 'verifymodel']

  def __init__(self, scenario):
    conf = scenario.getConfig()

    job = Job(conf)
    workflow = Workflow(conf)

    model = Model(conf)
    obs = Observations(conf)
    members = Members(conf)

    ea = ExternalAnalyses(conf, model.meshes)
    ss = StaticStream(conf, model.meshes, members, workflow.get('FirstCycleDate'))

    ic = InitIC(conf, model.meshes)
    hofx = HofX(conf, model.meshes, model)
    fc = Forecast(conf, model.meshes['Outer'], members, workflow)
    extfc = ExtendedForecast(conf, members, fc,)

    super().__init__(scenario)
