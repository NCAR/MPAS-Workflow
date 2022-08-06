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
  def __init__(self, config, hpc, obs, meshes, model, members, workflow):
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
    tasks = ['''
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

    dependencies = ['''
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

    self.var = Variational(config, hpc, meshes, model, members, workflow, self)
    tasks += self.var.tasks
    dependencies += self.var.dependencies

    self.rtpp = RTPP(config, hpc, meshes['Ensemble'], members, self)
    tasks += self.rtpp.tasks
    dependencies += self.rtpp.dependencies

    self.exportTasks(tasks)
    self.exportDependencies(dependencies)
