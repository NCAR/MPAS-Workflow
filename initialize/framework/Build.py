#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''
import os

from initialize.config.Component import Component
from initialize.config.Config import Config

from initialize.data.Model import Model

class Build(Component):
  variablesWithDefaults = {
    ## mpas bundle
    # mpas-bundle build directory
    'mpas bundle': ['/replace/this/in/host/specific/code/below', str],

    # optional double-precision build
    #'mpas bundle': ['/glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_22MAR2023', str],

    # forecast directory
    # defaults to bundle build, otherwise specify full directory
    #'forecast directory': ['bundle', str],
    'forecast directory': ['/replace/this/in/host/specific/code/below/', str],

    ## bundle compiler used
    # {compiler}-{mpi-implementation}/{version} combination that selects the JEDI module used to build
    # the executables described herein
    'bundle compiler used': ['gnu-openmpi', str,
      ['gnu-openmpi', 'intel-impi']],
  }

  def __init__(self, config:Config, model:Model=None):
    self.logPrefix = self.__class__.__name__+': '

    # set system dependent defaults before invoking Component ctor
    system = os.getenv('NCAR_HOST')
    if system == 'derecho':
      if config._bundle_dir != None:
        self.variablesWithDefaults['mpas bundle'] = [config._bundle_dir, str]
      else:
        self.variablesWithDefaults['mpas bundle'] = \
          ['/glade/work/taosun/Derecho/JEDI/mpas-bundle-v8.2/build', str] #actually this is Modelv8.2.1
      self.variablesWithDefaults['bundle compiler used'] = ['gnu-cray', str,
        ['gnu-cray', 'intel-cray']]
      self.variablesWithDefaults['forecast directory'] = ['bundle', str]

      # Ungrib
      wpsBuildDir = '/glade/work/jwittig/repos1/WPS/'
      # Mean state calculator
      # FIXME the source for the app in this directory was copied from
      # /glade/work/guerrett/pandac/work/meanState/spack-stack_gcc-10.1.0_openmpi-4.1.1
      # meanStateBuildDir = '/glade/work/jwittig/repos1/mpas-bundle-r2.0/build-gnu-derecho-single/bin'
      meanStateBuildDir = '/glade/work/jwittig/repos1/mpas-bundle-dev-new/build-gnu-1p-ss1.6.0/bin'
    elif system == 'cheyenne':
      self.variablesWithDefaults['mpas bundle'] = \
        ['/glade/p/mmm/parc/liuz/pandac_common/mpas-bundle-code-build/mpas_bundle_2.0_gnuSP/build', str]
      self.variablesWithDefaults['bundle compiler used'] = ['gnu-openmpi', str,
        ['gnu-openmpi', 'intel-cray']]
      self.variablesWithDefaults['forecast directory'] = \
        ['/glade/p/mmm/parc/liuz/pandac_common/mpas-bundle-code-build/mpas_bundle_2.0_gnuSP/MPAS_intelmpt', str]

      # Ungrib
      wpsBuildDir = '/glade/work/guerrett/pandac/data/GEFS'
      # Mean state calculator
      meanStateBuildDir = '/glade/work/guerrett/pandac/work/meanState/spack-stack_gcc-10.1.0_openmpi-4.1.1'
    else:
      self._msg('unknown host:' + system)
      wpsBuildDir = ''
      meanStateBuildDir = ''

    super().__init__(config)

    ###################
    # derived variables
    ###################

    # MPAS-JEDI
    # ---------
    ## Variational
    self._set('VariationalEXE', 'mpasjedi_variational.x')
    self._set('VariationalBuildDir', self['mpas bundle']+'/bin')

    ## EnsembleOfVariational
    self._set('EnsembleOfVariationalEXE', 'mpasjedi_eda.x')
    self._set('EnsembleOfVariationalBuildDir', self['mpas bundle']+'/bin')

    ## EnKF
    self._set('EnKFEXE', 'mpasjedi_enkf.x')
    self._set('EnKFBuildDir', self['mpas bundle']+'/bin')

    ## HofX
    self._set('HofXEXE', 'mpasjedi_hofx3d.x')
    self._set('HofXBuildDir', self['mpas bundle']+'/bin')

    ## RTPP
    self._set('RTPPEXE', 'mpasjedi_rtpp.x')
    self._set('RTPPBuildDir', self['mpas bundle']+'/bin')

    ## RTPS
    self._set('RTPSEXE', 'mpasjedi_rtps.x')
    self._set('RTPSBuildDir', self['mpas bundle']+'/bin')

    ## SACA
    self._set('SACAEXE', 'mpasjedi_addincrement.x')
    self._set('SACABuildDir', self['mpas bundle']+'/bin')

    if model is not None:

      # MPAS-Model
      # ----------
      self._set('InitBuildDir', self['mpas bundle']+'/bin')
      self._set('InitEXE', 'mpas_init_'+model['MPASCore'])

      # either use forecast executable from the bundle or a separate MPAS-Atmosphere build
      if self['forecast directory'] == 'bundle':
        self._set('ForecastBuildDir', self['mpas bundle']+'/bin')
        self._set('ForecastEXE', 'mpas_'+model['MPASCore'])
      else:
        self._set('ForecastBuildDir', self['forecast directory'])
        self._set('ForecastEXE', model['MPASCore']+'_model')

      if system == 'derecho':
        self._set('MPASLookupDir', self['mpas bundle']+'/MPAS/core_atmosphere')
        self._set('MPASLookupFileGlobs', ['.TBL', '.DBL', 'DATA', 'VERSION'])
      elif system == 'cheyenne':
        self._set('MPASLookupDir', self['mpas bundle']+'/MPAS/core_'+model['MPASCore'])
        self._set('MPASLookupFileGlobs', ['.TBL', '.DBL', 'DATA', 'COMPATABILITY', 'VERSION'])

      # Alternatively, use a stand-alone single-precision build of MPAS-A with GNU-MPT
      #self._set('ForecastBuildDir', '/glade/p/mmm/parc/liuz/pandac_common/20220309_mpas_bundle/code/MPAS-gnumpt-single')
      #self._set('ForecastEXE', model['MPASCore']+'_model')

      # Note: this also requires modifying bin/Forecast.csh:
      #-source config/environmentJEDI.csh
      #+source config/environmentMPT.csh
      #-  mpiexec ./${ForecastEXE}
      #-  #mpiexec_mpt ./${ForecastEXE}
      #+  #mpiexec ./${ForecastEXE}
      #+  mpiexec_mpt ./${ForecastEXE}


    # Non-bundle applications
    # =======================

    # Ungrib
    # ------
    self._set('ungribEXE', 'ungrib.exe')
    self._set('WPSBuildDir', wpsBuildDir)

    # Obs2IODA-v2
    # -----------
    self._set('obs2iodaEXE', 'obs2ioda-v2.x')
    self._set('obs2iodaBuildDir', '/glade/campaign/mmm/parc/ivette/pandac/fork_obs2ioda/obs2ioda/obs2ioda-v2/src')
    self._set('iodaUpgradeEXE1', 'ioda-upgrade-v1-to-v2.x')
    self._set('iodaUpgradeEXE2', 'ioda-upgrade-v2-to-v3.x')
    self._set('iodaUpgradeBuildDir', self['mpas bundle']+'/bin')

    # Mean state calculator
    # ---------------------
    #self._set('meanStateExe', 'mpasjedi_ens_mean_variance.x')
    #self._set('meanStateBuildDir', '/glade/work/taosun/Derecho/MPAS/JEDI_MPAS/build_intel'+'/bin')
    self._set('meanStateExe', 'average_netcdf_files_parallel_mpas.x')
    self._set('meanStateBuildDir', meanStateBuildDir)

    self._cshVars = list(self._vtable.keys())
