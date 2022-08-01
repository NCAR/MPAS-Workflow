#!/usr/bin/env python3

from collections import OrderedDict

from initialize.Component import Component
from initialize.subconfig.RTPP import RTPP
from initialize.subconfig.Variational import Variational

class DataAssimilation(Component):
  '''
  Framework for all DataAssimilation applications.  Can be used to manage interdependent classes
  and cylc tasks, but does not execute any tasks on its own.
  '''
  baseKey = 'da'

  def __init__(self, config, obs, meshes, model, members, workflow):
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

    tasks = ['''
  ## data assimilation task markers
  [['''+self.pre+''']]
  [['''+self.init+''']]
  [['''+self.execute+''']]
  [['''+self.post+''']]
  [['''+self.finished+''']]
  [['''+self.clean+''']]''']

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

    self.var = Variational(config, meshes, model, members, workflow, self)
    tasks += self.var.tasks
    dependencies += self.var.dependencies

    self.rtpp = RTPP(config, meshes['Ensemble'], members, self)
    tasks += self.rtpp.tasks
    dependencies += self.rtpp.dependencies

    self.exportTasks(tasks)
    self.exportDependencies(dependencies)
