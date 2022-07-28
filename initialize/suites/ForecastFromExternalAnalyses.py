#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.ExternalAnalyses import ExternalAnalyses
from initialize.subconfig.Job import Job
from initialize.subconfig.Members import Members
from initialize.subconfig.Model import Model
from initialize.subconfig.Workflow import Workflow

class ForecastFromExternalAnalyses(Suite):
  ExpConfigType = 'base'
  appIndependentConfigs = ['observations']
  appDependentConfigs = ['forecast', 'hofx', 'initic', 'verifyobs', 'verifymodel']

  def __init__(self, scenario):
    conf = scenario.getConfig()
    job = Job(conf)
    members = Members(conf)
    model = Model(conf)
    workflow = Workflow(conf)
    ea = ExternalAnalyses(conf, model.meshes)
    ss = StaticStream(conf, model.meshes, members, workflow.get('FirstCycleDate'))

    super().__init__(scenario)
