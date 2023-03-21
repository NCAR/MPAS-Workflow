#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.config.Component import Component

class Example(Component):
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

  def __init__(self, config:Config):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    self._tasks = ['''
  [[Example0]]
  [[Example1]]
''']

    self._dependencies = ['''
  Example0 => Example1
''']
