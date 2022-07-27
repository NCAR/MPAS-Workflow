#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.Job import Job
from initialize.subconfig.Workflow import Workflow

class Cycle(Suite):
  ExpConfigType = 'cycling'
  appIndependentConfigs = ['externalanalyses', 'firstbackground', 'model', 'observations']
  appDependentConfigs = ['ensvariational', 'forecast', 'hofx', 'initic', 'rtpp', 'variational', 'verifyobs', 'verifymodel']

  def __init__(self, scenario):
    conf = scenario.get()
    job = Job(conf)
    wf = Workflow(conf)
    #TODO: remove below line when all components are migrated to python, turn off for testing for now
    #super().__init__(scenario)
