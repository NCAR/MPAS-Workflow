#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.components.Build import Build
from initialize.components.HPC import HPC
from initialize.components.Workflow import Workflow
from initialize.components.Observations import Observations

class GenerateObs(Suite):
  ExpConfigType = 'base'
  def __init__(self, scenario):
    conf = scenario.getConfig()

    build = Build(conf, None)
    hpc = HPC(conf)
    workflow = Workflow(conf)

    obs = Observations(conf, hpc)
