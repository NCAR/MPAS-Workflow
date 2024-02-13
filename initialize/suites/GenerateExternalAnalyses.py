#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.applications.InitIC import InitIC
# TODO: make members optional, modify getCycleVars
from initialize.applications.Members import Members

from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.Model import Model

from initialize.framework.Build import Build
from initialize.framework.Experiment import Experiment
from initialize.framework.Naming import Naming

from initialize.suites.SuiteBase import SuiteBase

class GenerateExternalAnalyses(SuiteBase):
  def __init__(self, conf:Config):
    super().__init__(conf)

    self.c['model'] = Model(conf)
    self.c['build'] = Build(conf, self.c['model'])
    self.c['externalanalyses'] = ExternalAnalyses(conf, self.c['hpc'], self.c['model'].getMeshes())
    self.c['initic'] = InitIC(conf, self.c['hpc'], self.c['model'].getMeshes(), self.c['externalanalyses'])
    self.c['experiment'] = Experiment(conf, self.c['hpc'])
    self.c['naming'] = Naming(conf, self.c['experiment'])

    # TODO: make members optional, modify getCycleVars
    self.c['members'] = Members(conf)

    for k, c_ in self.c.items():
      c_.export()

    self._dependencies += ['''
    PT'''+str(self.c['workflow']['CyclingWindowHR'])+'''H
      = '''+self.c['externalanalyses']['PrepareExternalAnalysisOuter']]

    self.taskComponents += [
      'externalanalyses',
      'initic',
    ]
