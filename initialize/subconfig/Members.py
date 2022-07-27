#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Members(SubConfig):
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
    n = self.get('n')
    if n is None:
      self._set('nMembers', 0)
    else:
      self._set('nMembers', n)

    # EMPTY

    ###############################
    # export for use outside python
    ###############################
    self.exportVars(['nMembers'], ['nMembers'])
