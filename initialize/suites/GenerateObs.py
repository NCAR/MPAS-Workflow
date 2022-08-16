#!/usr/bin/env python3

from initialize.Config import Config
from initialize.Suite import Suite
from initialize.components.Build import Build
from initialize.components.Experiment import Experiment
from initialize.components.HPC import HPC
from initialize.components.Members import Members
from initialize.components.Model import Model
from initialize.components.Naming import Naming
from initialize.components.Workflow import Workflow
from initialize.components.Observations import Observations

class GenerateObs(Suite):
  def __init__(self, conf:Config):
    c = {}
    c['build'] = Build(conf, None)
    c['hpc'] = HPC(conf)
    c['workflow'] = Workflow(conf)
    c['obs'] = Observations(conf, c['hpc'])
    c['exp'] = Experiment(conf, c['hpc'])
    c['naming'] = Naming(conf, c['exp'])

    # TODO: make members optional, modify getCycleVars
    c['members'] = Members(conf)

    for c_ in c.values():
      c_.export()
