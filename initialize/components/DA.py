#!/usr/bin/env python3

from collections import OrderedDict

from initialize.Component import Component
from initialize.components.RTPP import RTPP
from initialize.components.Variational import Variational

class DA(Component):
  '''
  Framework for all data assimilation (DA) applications.  Can be used to manage interdependent classes
  and cylc tasks, but does not execute any tasks on its own.
  '''
  def __init__(self, config, hpc, obs, meshes, model, members, workflow, build):
    super().__init__(config)

    ########################
    # tasks and dependencies
    ########################

    # For each of the cylc "task" below, some are family names, while others are marker names
    # + "family" tasks can be used for inheritance; those marked with a * must be used in order
    #   to avoid an error message caused by the ":succeed-all" qualifier
    # + "marker" tasks can be used in dependency graphs only
    #TODO: provide mechanism for multiple serial pre and post tasks
    self.pre = 'PreDA' # marker
    self.init = 'InitDA' # family*
    self.execute = 'DA' # family*
    self.post = 'DAPost' # marker
    self.finished = 'DAFinished' # marker
    self.clean = 'CleanDA' # family

    self.groupName = 'DAFamily'
    self._tasks = ['''
  ## data assimilation task markers
  [['''+self.groupName+''']]
  [['''+self.pre+''']]
    inherit = '''+self.groupName+'''
  [['''+self.init+''']]
    inherit = '''+self.groupName+'''
  [['''+self.execute+''']]
    inherit = '''+self.groupName+'''
  [['''+self.post+''']]
    inherit = '''+self.groupName+'''
  [['''+self.finished+''']]
    inherit = '''+self.groupName+'''
  [['''+self.clean+''']]
    inherit = '''+self.groupName]

    self._dependencies = ['''
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

    msg = "DA: config must contain only one of variational or enkf"
    assert config.has('variational') or config.has('enkf'), msg

    if config.has('variational'):
      assert !config.has('enkf'), msg
      self.var = Variational(config, hpc, meshes, model, members, workflow, self)
      self.inputs = self.var.inputs
      self.outputs = self.var.outputs
    else:
      self.var = None

    if config.has('enkf'):
      assert !config.has('variational'), msg
      self.enkf = EnKF(config, hpc, meshes, model, members, workflow, self, build)
      self.inputs = self.enkf.inputs
      self.outputs = self.enkf.outputs
    else:
      self.enkf = None


    self.rtpp = RTPP(config, hpc, meshes['Ensemble'], members, self, self.inputs['members'], self.outputs['members'])

  def export(self, components):
    if self.var is not None: self.var.export(components)
    if self.enkf is not None: self.enkf.export(components)
    self.rtpp.export(components)
    super().export(components)
