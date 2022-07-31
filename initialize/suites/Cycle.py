#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.ExternalAnalyses import ExternalAnalyses
from initialize.subconfig.FirstBackground import FirstBackground
from initialize.subconfig.Job import Job
from initialize.subconfig.Members import Members
from initialize.subconfig.Model import Model
from initialize.subconfig.Observations import Observations
from initialize.subconfig.StaticStream import StaticStream
from initialize.subconfig.Workflow import Workflow

# applications
from initialize.subconfig.DataAssimilation import DataAssimilation
from initialize.subconfig.InitIC import InitIC
from initialize.subconfig.ExtendedForecast import ExtendedForecast
from initialize.subconfig.Forecast import Forecast
from initialize.subconfig.HofX import HofX

class Cycle(Suite):
  ExpConfigType = 'cycling'
  appDependentConfigs = ['verifyobs', 'verifymodel']

  def __init__(self, scenario):
    conf = scenario.getConfig()

    job = Job(conf)
    workflow = Workflow(conf)

    model = Model(conf)
    meshes = model.getMeshes()
    obs = Observations(conf)
    members = Members(conf)

    ea = ExternalAnalyses(conf, meshes)
    fb = FirstBackground(conf, meshes, members, workflow.get('FirstCycleDate'))
    ss = StaticStream(conf, meshes, members, workflow.get('FirstCycleDate'))

    ic = InitIC(conf, meshes)
    hofx = HofX(conf, meshes, model)
    da = DataAssimilation(conf, obs, meshes, model, members, workflow)
    fc = Forecast(conf, meshes['Outer'], members, workflow)
    extfc = ExtendedForecast(conf, members, fc)

    #TODO: remove below line when all components are migrated to python, turn off for testing for now
    super().__init__(scenario)
