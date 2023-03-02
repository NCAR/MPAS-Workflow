#!/usr/bin/env python3

import os
import subprocess

from initialize.applications.Members import Members
from initialize.applications.RTPP import RTPP
from initialize.applications.Variational import Variational

from initialize.config.Component import Component
from initialize.config.Config import Config

from initialize.framework.HPC import HPC

class Experiment(Component):
  PackageBaseName = 'MPAS-Workflow'

  ## ExperimentDirectory
  # Auto-generated directory location of this experiment
  # Will be constructd using
  # hpc['top directory']+'/'+self['user directory']+'/'+self['user directory child']+'/'+SuiteName

  # SuiteName is constructed as self['prefix']+self['name']+self['suffix']

  optionalVariables = {
    ## name
    # leave as None to be automatically generated from critical config elements
    # Note: when running multiple scenarios simultaneously, setting name explicitly for
    # each scenario is the safest way to ensure that two scenarios do not have identically
    # auto-generated name's
    'name': str,

    ## user directory
    # subdirectory within ParentDirectoryPrefix where experiments are located
    # leave as None to be assigned with os.getenv('USER')
    'user directory': str,

    ## prefix
    # prefix to name when building SuiteName
    # leave as None to be assigned with os.getenv('USER')+'_'
    'prefix': str,
  }
  variablesWithDefaults = {
    ## suffix
    'suffix': ['', str],

    ## user directory child
    'user directory child': ['pandac', str],
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
    meshes:dict=None,
    variational:Variational=None,
    members:Members=None,
    rtpp:RTPP=None,
  ):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    suiteName = self['name']
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
        if 'Inner' in meshes:
          mI = meshes['Inner'].name
          if mI != mO:
            name_ += 'I'+mI
        if 'Ensemble' in meshes:
          mE = meshes['Ensemble'].name
          if mE != mO and mE != mI:
            name_ += 'E'+mE

        name += '_'+name_

      assert name != '', ('Must give a valid name')

      suiteName = name

    user = os.getenv('USER')

    if self['user directory'] is None:
      self._set('user directory', user)

    if self['prefix'] is None:
      self._set('prefix', user+'_')

    ParentDirectory = hpc['top directory']+'/'+self['user directory']+'/'+self['user directory child']

    suiteName = self['prefix']+suiteName+self['suffix']
    self._set('SuiteName', suiteName)

    # ensure cylc suite parent directory exists
    cylcWorkDir = hpc['top directory']+'/'+user+'/cylc-run'
    self._set('cylcWorkDir', cylcWorkDir)
    cmd = ['mkdir', '-p', cylcWorkDir]
    self._msg(' '.join(cmd))
    sub = subprocess.run(cmd)

    ## absolute experiment directory
    self._set('ExperimentDirectory', ParentDirectory+'/'+suiteName)
    self._set('directory', ParentDirectory+'/'+suiteName)
    self._set('mainScriptDir', self['ExperimentDirectory']+'/'+self.PackageBaseName)
    self._set('ConfigDir', self['mainScriptDir']+'/config')
    self._set('ModelConfigDir', self['mainScriptDir']+'/config/mpas')
    self._set('title', self.PackageBaseName+'--'+self['SuiteName'])

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

    self._cshVars = ['cylcWorkDir', 'SuiteName', 'ExperimentDirectory', 'mainScriptDir', 'ConfigDir', 'ModelConfigDir']
    self._cylcVars = ['mainScriptDir', 'title']
