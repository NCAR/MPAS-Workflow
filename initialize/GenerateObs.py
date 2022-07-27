#!/usr/bin/env python3

import subprocess
from initialize.Suite import Suite
#from initialize.Config import Config

class GenerateObs(Suite):
  ExpConfigType = 'base'
  appIndependentConfigs = ['job', 'observations', 'workflow']
  appDependentConfigs = []

  def __init__(self, scenario):
    super().__init__(scenario)
