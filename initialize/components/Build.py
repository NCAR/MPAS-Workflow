#!/usr/bin/env python3

from initialize.Component import Component

class Build(Component):
  variablesWithDefaults = {
    ## mpas bundle
    # mpas-bundle build directory
    'mpas bundle': ['/glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_12JUL2022_single', str],

    ## compiler used
    # {compiler}-{mpi-implementation}/{version} combination that selects the JEDI module used to build
    # the executables described herein
    # OPTIONS: gnu-openmpi/10.1.0, intel-impi/19.1.1
    'compiler used': ['gnu-openmpi/10.1.0', str],
  }

  def __init__(self, config, model=None):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    if model is not None:
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
    self._set('iodaupgradeEXE', 'ioda-upgrade.x')
    self._set('iodaupgradeBuildDir', self['mpas bundle']+'/bin')

    # Mean state calculator
    # ---------------------
    self._set('meanStateExe', 'average_netcdf_files_parallel_mpas_gnu-openmpi.x')
    self._set('meanStateBuildDir', '/glade/work/guerrett/pandac/work/meanState')

    ###############################
    # export for use outside python
    ###############################
    csh = list(self._vtable.keys())
    self.exportVarsToCsh(csh)
