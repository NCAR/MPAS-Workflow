#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

# TODO: make members optional, modify getCycleVars
from initialize.applications.Members import Members

from initialize.config.Config import Config

from initialize.data.Observations import Observations

from initialize.framework.Build import Build
from initialize.framework.Experiment import Experiment
from initialize.framework.Naming import Naming

from initialize.suites.SuiteBase import SuiteBase


class GenerateObs(SuiteBase):
  def __init__(self, conf:Config):
    super().__init__(conf)

    self.c['build'] = Build(conf, None)
    self.c['observations'] = Observations(conf, self.c['hpc'])
    self.c['experiment'] = Experiment(conf, self.c['hpc'])
    self.c['naming'] = Naming(conf, self.c['experiment'])

    # TODO: make members optional, modify getCycleVars
    self.c['members'] = Members(conf)

    for k, c_ in self.c.items():
      c_.export()

    self._dependencies += ['''
    [[[PT'''+str(self.c['workflow']['CyclingWindowHR'])+'''H]]]
      graph = '''+self.c['observations']['PrepareObservations']]

    self.taskComponents += ['observations']
