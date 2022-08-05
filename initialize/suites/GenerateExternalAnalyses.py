#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.components.Build import Build
from initialize.components.Experiment import Experiment
from initialize.components.HPC import HPC
from initialize.components.Model import Model
from initialize.components.Naming import Naming
from initialize.components.Workflow import Workflow
from initialize.components.ExternalAnalyses import ExternalAnalyses

# applications
from initialize.components.InitIC import InitIC

class GenerateExternalAnalyses(Suite):
  def __init__(self, scenario):
    conf = scenario.getConfig()

    hpc = HPC(conf)
    workflow = Workflow(conf)

    model = Model(conf)
    build = Build(conf, model)

    ea = ExternalAnalyses(conf, hpc, model.meshes)

    ic = InitIC(conf, hpc, model.meshes)

    exp = Experiment(conf, hpc)

    #namedComponents = [ea]
    #naming = Naming(conf, exp, namedComponents)
    naming = Naming(conf, exp)
