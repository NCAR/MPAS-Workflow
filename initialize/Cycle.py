#!/usr/bin/env python3

import subprocess
from initialize.Suite import Suite
#from initialize.Config import Config

class Cycle(Suite):
  ExpConfigType = 'cycling'
  appIndependentConfigs = ['externalanalyses', 'firstbackground', 'job', 'model', 'observations', 'workflow']
  appDependentConfigs = ['ensvariational', 'forecast', 'hofx', 'initic', 'rtpp', 'variational', 'verifyobs', 'verifymodel']

  def __init__(self, scenario):
    super().__init__(scenario)
