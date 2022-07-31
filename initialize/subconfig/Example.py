#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Example(SubConfig):
  baseKey = 'example'
  #defaults = 'scenarios/defaults/example.yaml' (optional)
  requiredVariables = {
    'required int': int,
    'required float': float,
    'required str': str,
    'required bool': bool,
    'required list': list,
  }
  optionalVariables = {
    'optional int': int,
    'optional float': float,
    'optional str': str,
    'optional bool': bool,
    'optional list': list,
  }
  variablesWithDefaults = {
    'default int': [0, int],
    'default float': [0., float],
    'default str': ['0', str],
    'default bool': [False, bool],
    'default list': [[0, 0., '0'], list],
  }

  def __init__(self, config):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    # EMPTY

    ###############################
    # export for use outside python
    ###############################
    #cylc = list(self._vtable.keys())
    #self.exportVarsToCsh(csh)

    #csh = list(self._vtable.keys())
    #self.exportVarsToCylc(cylc)

    ########################
    # tasks and dependencies
    ########################
    #tasks = ['']
    #self.exportTasks(tasks)
    #dependencies = ['']
    #self.exportDependencies(dependencies)
