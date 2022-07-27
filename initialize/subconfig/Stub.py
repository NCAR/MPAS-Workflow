#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Stub(SubConfig):
  baseKey = 'stub'
  requiredVariables = {
  }
  variablesWithDefaults = {
  }
  def __init__(self, config):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    # EMPTY

    #################################
    # auto-generate shell config file
    #################################
    cshVariables = list(self._table.keys())
    cshStr = self.initCsh()
    for v in cshVariables:
      cshStr += self.varToCsh(v, self._table[v])

    self.write('config/stub.csh', cshStr)

    ##################################
    # auto-generate cylc include files
    ##################################
    cylcVariables = list(self._table.keys())
    cylcStr = []
    for v in cylcVariables:
      cylcStr += self.varToCylc(v, self._table[v])

    self.write('include/variables/auto/stub.rc', cylcStr)
