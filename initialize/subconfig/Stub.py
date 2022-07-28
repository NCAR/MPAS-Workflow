#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Stub(SubConfig):
  baseKey = 'stub'
  def __init__(self, config):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    # EMPTY

    ###############################
    # export for use outside python
    ###############################
    csh = list(self._vtable.keys())
    cylc = list(self._vtable.keys())
    self.exportVars(csh, cylc)
