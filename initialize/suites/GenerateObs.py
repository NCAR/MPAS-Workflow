#!/usr/bin/env python3

# TODO: make members optional, modify getCycleVars
from initialize.applications.Members import Members

from initialize.config.Config import Config

from initialize.data.Observations import Observations

from initialize.framework.Build import Build
from initialize.framework.Experiment import Experiment
from initialize.framework.HPC import HPC
from initialize.framework.Naming import Naming
from initialize.framework.Workflow import Workflow

from initialize.suites.Suite import Suite


class GenerateObs(Suite):
  def __init__(self, conf:Config):
    super().__init__()

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

    self._dependencies += ['''
    [[[PT'''+c['workflow']['CyclingWindowHR']+'''H]]]
      graph = '''+c['obs']['PrepareObservations']]
