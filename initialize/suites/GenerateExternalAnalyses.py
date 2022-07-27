#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.Job import Job
from initialize.subconfig.Model import Model
from initialize.subconfig.Workflow import Workflow

class GenerateExternalAnalyses(Suite):
  ExpConfigType = 'base'
  appIndependentConfigs = ['externalanalyses']
  appDependentConfigs = ['initic']

  def __init__(self, scenario):
    conf = scenario.get()
    job = Job(conf)
    model = Model(conf)
    workflow = Workflow(conf)

    super().__init__(scenario)
