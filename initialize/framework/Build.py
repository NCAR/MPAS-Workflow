#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.config.Component import Component
from initialize.config.Config import Config

from initialize.data.Model import Model

class Build(Component):
  variablesWithDefaults = {
    ## mpas bundle
    # mpas-bundle build directory
    'mpas bundle': ['/glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_14MAR2023_single', str],


    # optional double-precision build
    #'mpas bundle': ['/glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_14MAR2023', str],

    ## compiler used
    # {compiler}-{mpi-implementation}/{version} combination that selects the JEDI module used to build
    # the executables described herein
    'compiler used': ['gnu-openmpi', str,
      ['gnu-openmpi', 'intel-impi']],
  }

  def __init__(self, config:Config, model:Model=None):
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

    ## HofX
    self._set('HofXEXE', 'mpasjedi_hofx3d.x')
    self._set('HofXBuildDir', self['mpas bundle']+'/bin')

    ## RTPP
    self._set('RTPPEXE', 'mpasjedi_rtpp.x')
    self._set('RTPPBuildDir', self['mpas bundle']+'/bin')

    if model is not None:

      # MPAS-Model
      # ----------
      self._set('InitEXE', 'mpas_init_'+model['MPASCore'])
      self._set('InitBuildDir', self['mpas bundle']+'/bin')

      # use forecast executable built in the bundle
      self._set('ForecastBuildDir', self['mpas bundle']+'/bin')
      self._set('ForecastEXE', 'mpas_'+model['MPASCore'])

      self._set('MPASLookupDir', self['mpas bundle']+'/MPAS/core_'+model['MPASCore'])
      self._set('MPASLookupFileGlobs', ['.TBL', '.DBL', 'DATA', 'COMPATABILITY', 'VERSION'])

      # Alternatively, use a stand-alone single-precision build of MPAS-A with GNU-MPT
      #self._set('ForecastBuildDir', '/glade/p/mmm/parc/liuz/pandac_common/20220309_mpas_bundle/code/MPAS-gnumpt-single')
      #self._set('ForecastEXE', model['MPASCore']+'_model')

      # Note: this also requires modifying applications/forecast.csh:
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
    self._set('WPSBuildDir', '/glade/work/guerrett/pandac/data/GEFS')

    # Obs2IODA-v2
    # -----------
    self._set('obs2iodaEXE', 'obs2ioda-v2.x')
    self._set('obs2iodaBuildDir', '/glade/p/mmm/parc/ivette/pandac/fork_obs2ioda/obs2ioda/obs2ioda-v2/src')
    self._set('iodaUpgradeEXE1', 'ioda-upgrade-v1-to-v2.x')
    self._set('iodaUpgradeEXE2', 'ioda-upgrade-v2-to-v3.x')
    self._set('iodaUpgradeBuildDir', self['mpas bundle']+'/bin')

    # Mean state calculator
    # ---------------------
    self._set('meanStateExe', 'average_netcdf_files_parallel_mpas.x')
    self._set('meanStateBuildDir', '/glade/work/guerrett/pandac/work/meanState/spack-stack_gcc-10.1.0_openmpi-4.1.1')

    self._cshVars = list(self._vtable.keys())
