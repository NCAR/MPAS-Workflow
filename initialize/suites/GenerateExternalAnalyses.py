#!/usr/bin/env python3

from initialize.Suite import Suite
from initialize.subconfig.Job import Job
from initialize.subconfig.Model import Model
from initialize.subconfig.Workflow import Workflow
from initialize.subconfig.ExternalAnalyses import ExternalAnalyses

# applications
from initialize.subconfig.InitIC import InitIC

class GenerateExternalAnalyses(Suite):
  ExpConfigType = 'base'
  def __init__(self, scenario):
    conf = scenario.getConfig()
    job = Job(conf)
    workflow = Workflow(conf)

    model = Model(conf)

    ea = ExternalAnalyses(conf, model.meshes)

    ic = InitIC(conf, model.meshes)

    super().__init__(scenario)
