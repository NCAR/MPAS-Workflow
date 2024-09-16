#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.applications.SACA import SACA
from initialize.applications.ExtendedForecast import ExtendedForecast
from initialize.applications.ForecastSACA import ForecastSACA
from initialize.applications.Forecast import Forecast
from initialize.applications.InitIC import InitIC
from initialize.applications.Members import Members

from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.FirstBackground import FirstBackground
from initialize.data.Model import Model
from initialize.data.Observations import Observations
from initialize.data.InvariantStream import InvariantStream

from initialize.framework.Build import Build
from initialize.framework.Experiment import Experiment
from initialize.framework.Naming import Naming

from initialize.post.Benchmark import Benchmark

from initialize.suites.SuiteBase import SuiteBase

class CloudDirectInsertion(SuiteBase):
  def __init__(self, conf:Config):
    super().__init__(conf)

    self.c['model'] = Model(conf)
    meshes = self.c['model'].getMeshes()
    self.c['worklow'] = Workflow(conf)

    self.c['build'] = Build(conf, self.c['model'])
    self.c['observations'] = Observations(conf, self.c['hpc'])
    self.c['members'] = Members(conf)

    self.c['externalanalyses'] = ExternalAnalyses(conf, self.c['hpc'], meshes)
    self.c['initic'] = InitIC(conf, self.c['hpc'], meshes, self.c['externalanalyses'])

    self.c['saca'] = SACA(conf, self.c['hpc'], meshes['Outer'], self.c['workflow'])

    # Forecast object is only used to initialize parts of ExtendedForecast and ForecastSACA
    self.c['forecast'] = Forecast(conf, self.c['hpc'], meshes['Outer'], self.c['members'], self.c['model'], self.c['observations'],
                self.c['workflow'], self.c['externalanalyses'],
                self.c['externalanalyses'].outputs['state']['Outer'])

    self.c['firstbackground'] = FirstBackground(conf, self.c['hpc'], meshes, self.c['members'], self.c['workflow'],
                self.c['externalanalyses'],
                self.c['externalanalyses'].outputs['state']['Outer'], self.c['forecast'])

    self.c['forecastSACA'] = ForecastSACA(conf, self.c['hpc'], meshes['Outer'], self.c['members'], self.c['model'], self.c['observations'],
                self.c['workflow'], self.c['externalanalyses'],
                self.c['externalanalyses'].outputs['state']['Outer'],
                self.c['saca'].outputs['doMean'], self.c['saca'].outputs['meanTimes'], self.c['forecast'])

    self.c['extendedforecast'] = ExtendedForecast(conf, self.c['hpc'], self.c['members'], self.c['forecast'],
                self.c['externalanalyses'], self.c['observations'],
                self.c['saca'].outputs['state']['members'], 'external')

    self.c['experiment'] = Experiment(conf, self.c['hpc'])
    self.c['ss'] = InvariantStream(conf, meshes, self.c['workflow']['FirstCycleDate'], self.c['externalanalyses'], self.c['experiment'])

    self.c['naming'] = Naming(conf, self.c['experiment'])

    for k, c_ in self.c.items():
      if k in ['observations', 'initic', 'externalanalyses']:
        c_.export(self.c['extendedforecast']['extLengths'])
      elif k in ['forecastSACA']:
        c_.export("ExternalAnalysisReady__", self.c['externalanalyses'].outputs['state']['Outer'])
      elif k in ['saca']:
        c_.export(self.c['forecastSACA'].previousForecast)
      elif k in ['extendedforecast']:
        c_.export(self.c['saca'].tf.finished, activateEnsemble=False)
      elif k in ['forecast']:
        continue
      else:
        c_.export()

    self.queueComponents += [
      'externalanalyses',
      'initic',
      'observations',
    ]

    self.dependencyComponents += [
      'extendedforecast',
      'saca',
      'forecastSACA',
    ]
    self.taskComponents += [
      'extendedforecast',
      'externalanalyses',
      'initic',
      'observations',
      'saca',
      'forecastSACA',
      'firstbackground',
    ]
