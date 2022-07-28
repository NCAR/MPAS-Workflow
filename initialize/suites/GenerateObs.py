#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.Job import Job
from initialize.subconfig.Workflow import Workflow
from initialize.subconfig.Observations import Observations

class GenerateObs(Suite):
  ExpConfigType = 'base'
  def __init__(self, scenario):
    conf = scenario.getConfig()

    job = Job(conf)
    workflow = Workflow(conf)

    obs = Observations(conf)
