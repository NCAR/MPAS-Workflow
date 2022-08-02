#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.HPC import HPC
from initialize.subconfig.Workflow import Workflow
from initialize.subconfig.Observations import Observations

class GenerateObs(Suite):
  ExpConfigType = 'base'
  def __init__(self, scenario):
    conf = scenario.getConfig()

    hpc = HPC(conf)
    workflow = Workflow(conf)

    obs = Observations(conf, hpc)
