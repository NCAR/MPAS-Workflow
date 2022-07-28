#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.Job import Job
from initialize.subconfig.Workflow import Workflow

class GenerateObs(Suite):
  ExpConfigType = 'base'
  appIndependentConfigs = ['observations']
  appDependentConfigs = []

  def __init__(self, scenario):
    conf = scenario.getConfig()
    job = Job(conf)
    workflow = Workflow(conf)

    super().__init__(scenario)
