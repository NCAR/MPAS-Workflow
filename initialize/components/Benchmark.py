#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class Benchmark(Component):
  ObsCompareDir = 'CompareToBenchmark/obs'
  ModelCompareDir = 'CompareToBenchmark/model'
  optionalVariables = {
    'experiment directory': str,
  }
  variablesWithDefaults = {
    ## compare DA to benchmark: compare verification statistics files between two experiments
    #    after the DA verification completes
    'compare da to benchmark': [False, bool],

    ## compare BG to benchmark: compare verification statistics files between two experiments
    #    after the BGMembers verification completes
    'compare bg to benchmark': [False, bool],
  }


  def __init__(self, config, hpc, exp, naming):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    self._set('benchmark__ExperimentDirectory', self['experiment directory'])
    self._set('ObsCompareDir', self.ObsCompareDir)
    self._set('ModelCompareDir', self.ModelCompareDir)

    for v, value in naming.directories.items():
      benchDir = self['experiment directory']
      if benchDir is None: benchDir = exp['ExperimentDirectory']
      self._set('Benchmark'+v,
        value.replace(exp['ExperimentDirectory'], benchDir))

    self._cshVars = list(self._vtable.keys())
    self._cylcVars = ['compare da to benchmark', 'compare bg to benchmark']

    ########################
    # tasks and dependencies
    ########################

    attr = {
      'seconds': {'def': 300},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    job = Resource(self._conf, attr, ('job', 'compare'))
    task = TaskFactory[hpc.system](job)

    self._tasks = ['''
  [[Compare]]
'''+task.job()+task.directives()]
