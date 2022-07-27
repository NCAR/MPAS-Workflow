#!/usr/bin/env python3

from initialize.Suite import Suite
#from initialize.Config import Config

class ForecastFromExternalAnalyses(Suite):
  ExpConfigType = 'base'
  appIndependentConfigs = ['externalanalyses', 'job', 'members', 'model', 'observations', 'workflow']
  appDependentConfigs = ['forecast', 'hofx', 'initic', 'verifyobs', 'verifymodel']

  def __init__(self, scenario):
    super().__init__(scenario)
