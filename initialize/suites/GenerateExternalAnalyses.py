#!/usr/bin/env python3

from initialize.applications.InitIC import InitIC
# TODO: make members optional, modify getCycleVars
from initialize.applications.Members import Members

from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.Model import Model

from initialize.framework.Build import Build
from initialize.framework.Experiment import Experiment
from initialize.framework.HPC import HPC
from initialize.framework.Naming import Naming
from initialize.framework.Workflow import Workflow

from initialize.suites.Suite import Suite

class GenerateExternalAnalyses(Suite):
  def __init__(self, conf:Config):
    c = {}
    c['hpc'] = HPC(conf)
    c['workflow'] = Workflow(conf)
    c['model'] = Model(conf)
    c['build'] = Build(conf, c['model'])
    c['externalanalyses'] = ExternalAnalyses(conf, c['hpc'], c['model'].getMeshes())
    c['ic'] = InitIC(conf, c['hpc'], c['model'].getMeshes(), c['externalanalyses'])
    c['exp'] = Experiment(conf, c['hpc'])
    c['naming'] = Naming(conf, c['exp'])

    # TODO: make members optional, modify getCycleVars
    c['members'] = Members(conf)

    for c_ in c.values():
      c_.export()
