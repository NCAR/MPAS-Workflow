#!/usr/bin/env python3

import os
import subprocess

from initialize.Component import Component

class Experiment(Component):
  baseKey = 'experiment'

  PackageBaseName = 'MPAS-Workflow'

  ## ParentDirectory will be constructd using
  # hpc['top directory']+'/'+self['ExperimentUserDir']+'/'+self['ParentDirectoryChild']

  optionalVariables = {
    ## ExperimentName
    # leave as None to be automatically generated from critical config elements
    # Note: when using with run.csh and for multiple simultaneously running scenarios, setting
    # ExperimentName explicitly for all scenarios is the safest way to ensure that two scenarios do not
    # have identically auto-generated ExperimentName's
    'ExperimentName': str,

    ## ExperimentUserDir
    # subdirectory within ParentDirectoryPrefix where experiments are located
    # leave as None to be assigned with os.getenv('USER')
    'ExperimentUserDir': str,

    ## ExperimentUserPrefix
    # prefix of experiment name
    # leave as None to be assigned with os.getenv('USER')
    'ExperimentUserPrefix': str,
  }
  variablesWithDefaults = {
    ## ExpSuffix
    # a unique suffix to distinguish this experiment from others
    'ExpSuffix': ['', str],

    ## ParentDirectoryChild
    'ParentDirectoryChild': ['pandac', str],
  }

  def __init__(self, config, hpc, meshes=None, variational=None, members=None, rtpp=None):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    suiteName = self['ExperimentName']
    if suiteName is None:
      name = ''
      if variational is not None:
        name_ = variational['DAType']
        for nInner in variational['nInnerIterations']:
          name_ += '-'+str(nInner)
        name_ += '-iter'

        for o in variational['observations']:
          if o not in variational.benchmarkObservations:
            name_ += '_'+o

        if members is not None:
          if members.n > 1:
            name_ = 'eda_'+name_
            if variational['EDASize'] > 1:
              name_ += '_NMEM'+str(variational['nDAInstances'])+'x'+str(variational['EDASize'])
              if variational['MinimizerAlgorithm'] == variational['BlockEDA']:
                name_ += 'Block'
            else:
              name_ += '_NMEM'+str(members.n)

            if rtpp is not None:
              if rtpp['relaxationFactor'] > 0.0:
                name_ += '_RTPP'+str(rtpp['relaxationFactor'])

            if variational['SelfExclusion']:
              name_ += '_SelfExclusion'

            if variational['ABEInflation']:
              name_ += '_ABEI_BT'+str(variational['ABEIChannel'])

        name += name_

      if meshes is not None:
        name_ = ''
        mO = meshes['Outer'].name
        name_ = 'O'+mO
        mI = ''
        if meshes.has('Inner'):
          mI = meshes['Inner']
          if mI != mO:
            name_ += 'I'+mI
        if meshes.has('Ensemble'):
          mE = meshes['Ensemble']
          if mE != mO and mE != MI:
            name_ += 'E'+mE

        name += '_'+name_

      assert name != '', ('Must give a valid ExperimentName')

      suiteName = name

    user = os.getenv('USER')

    if self['ExperimentUserDir'] is None:
      self._set('ExperimentUserDir', user)

    if self['ExperimentUserPrefix'] is None:
      self._set('ExperimentUserPrefix', user+'_')

    ParentDirectory = hpc['top directory']+'/'+self['ExperimentUserDir']+'/'+self['ParentDirectoryChild']

    suiteName = self['ExperimentUserPrefix']+suiteName+self['ExpSuffix']
    self._set('SuiteName', suiteName)
    cylcWorkDir = hpc['top directory']+'/'+user+'/cylc-run'
    cmd = ['mkdir', '-p', cylcWorkDir]
    self._msg(' '.join(cmd))
    sub = subprocess.run(cmd)
    self._set('cylcWorkDir', cylcWorkDir)

    ## absolute experiment directory
    self._set('ExperimentDirectory', ParentDirectory+'/'+suiteName)
    self._set('mainScriptDir', self['ExperimentDirectory']+'/'+self.PackageBaseName)
    self._set('ConfigDir', self['mainScriptDir']+'/config')
    self._set('ModelConfigDir', self['mainScriptDir']+'/config/mpas')

    self._msg('')
    self._msg('======================================================================')
    self._msg('Setting up a new suite')
    self._msg('  SuiteName: '+self['SuiteName'])
    self._msg('  mainScriptDir: '+self['mainScriptDir'])
    self._msg('======================================================================')
    self._msg('')

    cmd = ['rm', '-rf', self['mainScriptDir']]
    self._msg(' '.join(cmd))
    sub = subprocess.run(cmd)

    cmd = ['mkdir', '-p', self['mainScriptDir']]
    self._msg(' '.join(cmd))
    sub = subprocess.run(cmd)

    self._msg('')

    ###############################
    # export for use outside python
    ###############################
    csh = ['cylcWorkDir', 'SuiteName', 'ExperimentDirectory', 'mainScriptDir', 'ConfigDir', 'ModelConfigDir']
    self.exportVarsToCsh(csh)

    self._set('title', self.PackageBaseName+'--'+self['SuiteName'])
    cylc = ['mainScriptDir', 'title']
    self.exportVarsToCylc(cylc)
