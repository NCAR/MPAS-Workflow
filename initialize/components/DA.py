#!/usr/bin/env python3

from collections import OrderedDict

from initialize.Component import Component
from initialize.components.RTPP import RTPP
from initialize.components.Variational import Variational
from initialize.components.EnKF import EnKF

class DA(Component):
  '''
  Framework for all data assimilation (DA) applications.  Can be used to manage interdependent classes
  and cylc tasks, but does not execute any tasks on its own.
  '''
  workDir = 'CyclingDA'
  analysisPrefix = 'an'
  backgroundPrefix = 'bg'

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

    ## DA
    # application
    msg = "DA: config must contain only one of variational or enkf"
    assert config.has('variational') or config.has('enkf'), msg

    if config.has('variational'):
      assert not config.has('enkf'), msg
      self.var = Variational(config, hpc, meshes, model, members, workflow, self)
      if members.n > 1:
        memFmt = '/mem{:03d}'
      else:
        # TODO: eliminate this branch, may require modifications to verification
        #   in the end, verification should just take the inputs/outputs defined below
        memFmt = ''
    else:
      self.var = None

    if config.has('enkf'):
      assert not config.has('variational'), msg
      self.enkf = EnKF(config, hpc, meshes, model, members, workflow, self, build)
      memFmt = '/mem{:03d}'
    else:
      self.enkf = None

    # inputs/outputs
    self.inputs = {}
    self.inputs['members'] = []
    self.outputs = {}
    self.outputs['members'] = []
    for mm in range(1, members.n+1, 1):
      self.inputs['members'].append({
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.backgroundPrefix+memFmt.format(mm),
        'prefix': self.backgroundPrefix,
      })
      self.outputs['members'].append({
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.analysisPrefix+memFmt.format(mm),
        'prefix': self.analysisPrefix,
      })

    self.inputs['mean'] = {
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.backgroundPrefix+'/mean',
        'prefix': self.backgroundPrefix,
    }
    self.outputs['mean'] = {
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.analysisPrefix+'/mean',
        'prefix': self.analysisPrefix,
    }

    ## RTPP
    self.rtpp = RTPP(config, hpc, meshes['Outer'], members, self, self.inputs['members'], self.outputs['members'])

  def export(self, components):
    if self.var is not None: self.var.export(components)
    if self.enkf is not None: self.enkf.export(components)
    self.rtpp.export(components)
    super().export(components)
