#!/usr/bin/env python3

from initialize.Config import Config
from initialize.Suite import Suite
from initialize.components.Build import Build
from initialize.components.Experiment import Experiment
from initialize.components.HPC import HPC
from initialize.components.Naming import Naming
from initialize.components.Workflow import Workflow
from initialize.components.Observations import Observations

class GenerateObs(Suite):
  def __init__(self, conf:Config):
    build = Build(conf, None)
    hpc = HPC(conf)
    workflow = Workflow(conf)

    obs = Observations(conf, hpc)

    exp = Experiment(conf, hpc)

    #namedComponents = [obs]
    #naming = Naming(conf, exp, namedComponents)
    naming = Naming(conf, exp)
