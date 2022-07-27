#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.Job import Job

class Cycle(Suite):
  ExpConfigType = 'cycling'
  appIndependentConfigs = ['externalanalyses', 'firstbackground', 'model', 'observations', 'workflow']
  appDependentConfigs = ['ensvariational', 'forecast', 'hofx', 'initic', 'rtpp', 'variational', 'verifyobs', 'verifymodel']

  def __init__(self, scenario):
    conf = scenario.get()
    job = Job(conf)
    super().__init__(scenario)
