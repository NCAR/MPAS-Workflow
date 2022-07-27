#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.Job import Job
from initialize.subconfig.Members import Members
from initialize.subconfig.Model import Model
from initialize.subconfig.Workflow import Workflow

class ForecastFromExternalAnalyses(Suite):
  ExpConfigType = 'base'
  appIndependentConfigs = ['externalanalyses', 'observations']
  appDependentConfigs = ['forecast', 'hofx', 'initic', 'verifyobs', 'verifymodel']

  def __init__(self, scenario):
    conf = scenario.get()
    job = Job(conf)
    members = Members(conf)
    model = Model(conf)
    workflow = Workflow(conf)

    super().__init__(scenario)
