#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.applications.SACA import SACA
from initialize.applications.DA import DA
from initialize.applications.ExtendedForecast import ExtendedForecast
from initialize.applications.Forecast import Forecast
from initialize.applications.InitIC import InitIC
from initialize.applications.Members import Members

from initialize.config.Config import Config

from initialize.data.ExternalAnalyses import ExternalAnalyses
from initialize.data.FirstBackground import FirstBackground
from initialize.data.Model import Model
from initialize.data.Observations import Observations
from initialize.data.StaticStream import StaticStream

from initialize.framework.Build import Build
from initialize.framework.Experiment import Experiment
from initialize.framework.Naming import Naming

from initialize.post.Benchmark import Benchmark

from initialize.suites.SuiteBase import SuiteBase


class CloudDirectInsertionCycle(SuiteBase):
  def __init__(self, conf:Config):
    super().__init__(conf)

    self.c['model'] = Model(conf)
    self.c['build'] = Build(conf, self.c['model'])
    meshes = self.c['model'].getMeshes()
    self.c['observations'] = Observations(conf, self.c['hpc'])
    self.c['members'] = Members(conf)

    self.c['saca'] = SACA(conf, self.c['hpc'], meshes['Outer'], self.c['workflow'])
    runDASaca = self.c['saca'].outputs['runDASaca']

    self.c['externalanalyses'] = ExternalAnalyses(conf, self.c['hpc'], meshes)
    self.c['initic'] = InitIC(conf, self.c['hpc'], meshes, self.c['externalanalyses'])

    self.c['da'] = DA(conf, self.c['hpc'], self.c['observations'], meshes, self.c['model'], self.c['members'], self.c['workflow'])
    self.c['forecast'] = Forecast(conf, self.c['hpc'], meshes['Outer'], self.c['members'], self.c['model'],
                self.c['observations'], self.c['workflow'], self.c['externalanalyses'],
                self.c['da'].outputs['state']['members'])

    self.c['firstbackground'] = FirstBackground(conf, self.c['hpc'], meshes, self.c['members'], self.c['workflow'],
                self.c['externalanalyses'],
                self.c['externalanalyses'].outputs['state']['Outer'], self.c['forecast'])
 
    self.c['extendedforecast'] = ExtendedForecast(conf, self.c['hpc'], self.c['members'], self.c['forecast'],
                self.c['externalanalyses'], self.c['observations'],
                self.c['da'].outputs['state']['members'], 'internal')

    #if conf.has('benchmark'): # TODO: make benchmark optional,
    # and depend on whether verifyobs/verifymodel are selected
    self.c['benchmark'] = Benchmark(conf, self.c['hpc'])

    # provide default title in case one is not specified
    meshTitle = ''
    mO = meshes['Outer'].name
    meshTitle = 'O'+mO
    mI = meshes['Inner'].name
    if mI != mO:
      meshTitle += 'I'+mI
    mE = meshes['Ensemble'].name
    if mE != mO and mE != mI:
      meshTitle += 'E'+mE

    defaultTitle = self.c['da'].title+'_'+meshTitle

    self.c['experiment'] = Experiment(conf, self.c['hpc'], defaultTitle)

    self.c['ss'] = StaticStream(conf, meshes, self.c['members'], self.c['workflow']['FirstCycleDate'],
                self.c['externalanalyses'], self.c['experiment'])

    self.c['naming'] = Naming(conf, self.c['experiment'], self.c['benchmark'])

    for k, c_ in self.c.items():
      if runDASaca == 'afterDA':
        if k in ['observations', 'initic', 'externalanalyses']:
          c_.export(self.c['extendedforecast']['extLengths'])
        elif k in ['saca']:
          c_.export(self.c['da'].tf.finished)
        elif k in ['forecast']:
          c_.export(self.c['saca'].tf.finished, self.c['da'].meanBGDir)
        elif k in ['da']:
          # TODO: DA.export should take Forecast.output['state']['members] as input arg
          c_.export(self.c['forecast'].previousForecast, self.c['extendedforecast'])
        elif k in ['extendedforecast']:
          c_.export(self.c['saca'].tf.finished, activateEnsemble=False)
        else:
          c_.export()
      elif runDASaca == 'beforeDA':
        if k in ['observations', 'initic', 'externalanalyses']:
          c_.export(self.c['extendedforecast']['extLengths'])
        elif k in ['saca']:
          c_.export(self.c['forecast'].previousForecast)
        elif k in ['da']:
          # TODO: DA.export should take Forecast.output['state']['members] as input arg
          c_.export(self.c['saca'].tf.finished, self.c['extendedforecast'])
        elif k in ['forecast']:
          c_.export(self.c['da'].tf.finished, self.c['da'].meanBGDir)
        elif k in ['extendedforecast']:
          c_.export(self.c['da'].tf.finished, activateEnsemble=False)
        else:
          c_.export()

    self.queueComponents += [
      'externalanalyses',
      'initic',
      'observations',
    ]

    self.dependencyComponents += [
      'da',
      'forecast',
      'firstbackground',
      'extendedforecast',
      'saca',
    ]

    self.taskComponents += [
      'benchmark',
      'da',
      'forecast',
      'firstbackground',
      'extendedforecast',
      'externalanalyses',
      'initic',
      'observations',
      'saca',
    ]
