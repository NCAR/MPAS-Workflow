#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.ExternalAnalyses import ExternalAnalyses
from initialize.subconfig.FirstBackground import FirstBackground
from initialize.subconfig.Job import Job
from initialize.subconfig.Members import Members
from initialize.subconfig.Model import Model
from initialize.subconfig.Observations import Observations
from initialize.subconfig.StaticStream import StaticStream
from initialize.subconfig.Workflow import Workflow

# applications
from initialize.subconfig.InitIC import InitIC
from initialize.subconfig.HofX import HofX
from initialize.subconfig.Variational import Variational

class Cycle(Suite):
  ExpConfigType = 'cycling'
  appDependentConfigs = ['forecast', 'rtpp', 'verifyobs', 'verifymodel']

  def __init__(self, scenario):
    conf = scenario.getConfig()

    job = Job(conf)
    workflow = Workflow(conf)

    model = Model(conf)
    obs = Observations(conf)
    members = Members(conf)

    ea = ExternalAnalyses(conf, model.meshes)
    fb = FirstBackground(conf, model.meshes, members, workflow.get('FirstCycleDate'))
    ss = StaticStream(conf, model.meshes, members, workflow.get('FirstCycleDate'))

    ic = InitIC(conf, model.meshes)
    hofx = HofX(conf, model.meshes, model)
    var = Variational(conf, model.meshes, model, members, workflow)

    #TODO: remove below line when all components are migrated to python, turn off for testing for now
    super().__init__(scenario)
