#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

from initialize.framework.HPC import HPC

class Benchmark(Component):
  ObsCompareDir = 'CompareToBenchmark/obs'
  ModelCompareDir = 'CompareToBenchmark/model'
  optionalVariables = {
    'directory': str,
  }
  variablesWithDefaults = {
    ## compare DA to benchmark: compare verification statistics files between two experiments
    #    after the DA verification completes
    'compare da to benchmark': [False, bool],

    ## compare BG to benchmark: compare verification statistics files between two experiments
    #    after the BGMembers verification completes
    'compare bg to benchmark': [False, bool],
  }


  def __init__(self, config:Config, hpc:HPC):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    self._set('ObsCompareDir', self.ObsCompareDir)
    self._set('ModelCompareDir', self.ModelCompareDir)

    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################

    attr = {
      'seconds': {'def': 300},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    job = Resource(self._conf, attr, ('job', 'compare'))
    task = TaskLookup[hpc.system](job)

    self._tasks = ['''
  [[Compare]]
'''+task.job()+task.directives()]
