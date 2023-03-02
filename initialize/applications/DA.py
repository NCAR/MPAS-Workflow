#!/usr/bin/env python3

from collections import OrderedDict

from initialize.applications.Members import Members
from initialize.applications.RTPP import RTPP
from initialize.applications.Variational import Variational

from initialize.config.Component import Component
from initialize.config.Config import Config

from initialize.data.Model import Model
from initialize.data.Observations import Observations

from initialize.framework.HPC import HPC
from initialize.framework.Workflow import Workflow

class DA(Component):
  '''
  Framework for all data assimilation (DA) applications.  Can be used to manage interdependent classes
  and cylc tasks, but does not execute any tasks on its own.
  '''
  # For each of these DA cylc "task" names, some are family names, while others are marker names
  # + "family" tasks can be used for inheritance; those marked with a * must be used in order
  #   to avoid an error message caused by the ":succeed-all" qualifier
  # + "marker" tasks can be used in dependency graphs only
  #TODO: provide mechanism for multiple serial pre and post tasks
  pre = 'PreDA' # marker
  init = 'InitDA' # family*
  execute = 'DA' # family*
  post = 'DAPost' # marker
  finished = 'DAFinished' # marker
  clean = 'CleanDA' # family
  phases = [pre, init, execute, post, finished, clean]

  def __init__(self,
    config:Config,
    hpc:HPC,
    obs:Observations,
    meshes:dict,
    model:Model,
    members:Members,
    workflow:Workflow,
  ):
    super().__init__(config)

    ########################
    # tasks and dependencies
    ########################

    self.groupName = 'DAFamily'
    self._tasks += ['''
  ## data assimilation task markers
  [['''+self.groupName+''']]''']
    for p in self.phases:
      self._tasks += ['''
  [['''+p+''']]''']

    self._dependencies += ['''
        # pre => init => execute:succeed-all => post => finished => clean
        # pre-da observation processing
        {{'''+obs.workflow+'''}} => '''+self.pre+'''

        # init
        '''+self.pre+''' => '''+self.init+'''

        ## data assimilation
        '''+self.init+''':succeed-all => '''+self.execute+'''

        ## post-da
        # all DA sub-tasks must succeed in order to start post
        '''+self.execute+''':succeed-all => '''+self.post+'''

        # finished after post, clean after finished
        '''+self.post+''' => '''+self.finished+''' => '''+self.clean]

    self.var = Variational(config, hpc, meshes, model, obs, members, workflow, self)
    self.outputs = self.var.outputs
    self.rtpp = RTPP(config, hpc, meshes['Ensemble'], members, self,
                     self.var.inputs['state']['members'], self.var.outputs['state']['members'])

  def export(self, components):
    self.var.export(components)
    self.rtpp.export(components)
    super().export(components)
