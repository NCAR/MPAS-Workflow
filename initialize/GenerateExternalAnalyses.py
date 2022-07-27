#!/usr/bin/env python3

import subprocess
from initialize.Suite import Suite
#from initialize.Config import Config

class GenerateExternalAnalyses(Suite):
  ExpConfigType = 'base'
  appIndependentConfigs = ['externalanalyses', 'job', 'model', 'workflow']
  appDependentConfigs = ['initic']

  def __init__(self, scenario):
    super().__init__(scenario)
