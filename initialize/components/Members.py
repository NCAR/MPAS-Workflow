#!/usr/bin/env python3

from initialize.Component import Component

class Members(Component):
  baseKey = 'members'
  optionalVariables = {
    ## n: number of firstbackground, DA, and forecast members
    'n': int,
  }
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

    ###############################
    # export for use outside python
    ###############################
    self.exportVarsToCsh(['nMembers'])
    self.exportVarsToCylc(['nMembers'])
