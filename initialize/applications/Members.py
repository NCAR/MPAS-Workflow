#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.config.Component import Component
from initialize.config.Config import Config

class Members(Component):
  optionalVariables = {
    ## n: number of firstbackground, DA, and forecast members
    'n': int,
  }

  fmt = '/mem{:03d}'

  def __init__(self, config):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    n = self['n']
    if n is None:
      self._set('nMembers', 0)
      self.n = 0
    else:
      self._set('nMembers', n)
      self.n = n

    self._cshVars = ['nMembers']

    if self.n > 1:
      self.memFmt = self.fmt
    else:
      self.memFmt = ''
