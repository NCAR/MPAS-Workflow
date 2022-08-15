#!/usr/bin/env python3

from initialize.Config import Config
from initialize.Suite import Suite
from initialize.components.Benchmark import Benchmark
from initialize.components.Build import Build
from initialize.components.Experiment import Experiment
from initialize.components.HPC import HPC
from initialize.components.Members import Members
from initialize.components.Model import Model
from initialize.components.Naming import Naming
from initialize.components.Workflow import Workflow
from initialize.components.ExternalAnalyses import ExternalAnalyses

# applications
from initialize.components.InitIC import InitIC

class GenerateExternalAnalyses(Suite):
  def __init__(self, conf:Config):
    c = {}
    c['hpc'] = HPC(conf)
    c['workflow'] = Workflow(conf)
    c['model'] = Model(conf)
    c['build'] = Build(conf, c['model'])
    c['ea'] = ExternalAnalyses(conf, c['hpc'], c['model'].getMeshes())
    c['ic'] = InitIC(conf, c['hpc'], c['model'].getMeshes())
    c['exp'] = Experiment(conf, c['hpc'])
    c['naming'] = Naming(conf, c['exp'])

    # TODO: make members, benchmark optional, modify getCycleVars
    c['members'] = Members(conf)
    c['bench'] = Benchmark(conf, c['hpc'], c['exp'], c['naming'])

    for c_ in c.values():
      c_.export()
