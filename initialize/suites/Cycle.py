#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.Job import Job
from initialize.subconfig.Members import Members
from initialize.subconfig.Model import Model
from initialize.subconfig.Workflow import Workflow
from initialize.subconfig.ExternalAnalyses import ExternalAnalyses

class Cycle(Suite):
  ExpConfigType = 'cycling'
  appIndependentConfigs = ['firstbackground', 'observations']
  appDependentConfigs = ['ensvariational', 'forecast', 'hofx', 'initic', 'rtpp', 'variational', 'verifyobs', 'verifymodel']

  def __init__(self, scenario):
    conf = scenario.get()
    job = Job(conf)
    members = Members(conf)
    model = Model(conf)
    workflow = Workflow(conf)
    ea = ExternalAnalyses(conf, model.meshes)

    #TODO: remove below line when all components are migrated to python, turn off for testing for now
    #super().__init__(scenario)
