#!/bin/csh -f

if ( $?config_builds ) exit 0
set config_builds = 1

#############################
## build directory structures
#############################

## BuildCompiler
# {compiler}-{mpi-implementation} combination that selects the JEDI module to be loaded in
# config/environmentForJedi.csh
# OPTIONS: gnu-openmpi, intel-impi
setenv BuildCompiler 'gnu-openmpi'

# Note: at this time, all executables should be built in the same environment, one that is
# consistent with config/environmentForJedi.csh

#set commonBuild = /glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_16MAR2022
set commonBuild = /glade/scratch/ivette/jedi_tropopause/debug/build

# Ungrib
setenv ungribEXE ungrib.exe
setenv WPSBuildDir /glade/work/guerrett/pandac/data/GEFS

# Obs2IODA-v2
setenv obs2iodaEXEC obs2ioda-v2.x
setenv obs2iodaBuildDir /glade/p/mmm/parc/ivette/pandac/fork_obs2ioda/obs2ioda/obs2ioda-v2/src
setenv iodaupgradeEXEC ioda-upgrade.x
setenv iodaupgradeBuildDir ${commonBuild}/bin

# MPAS-JEDI
# ---------
## Variational
setenv VariationalEXE mpasjedi_variational.x
setenv VariationalBuildDir ${commonBuild}/bin

## EnsembleOfVariational
setenv EnsembleOfVariationalEXE mpasjedi_eda.x
setenv EnsembleOfVariationalBuildDir ${commonBuild}/bin

## HofX
setenv HofXEXE mpasjedi_hofx3d.x
setenv HofXBuildDir ${commonBuild}/bin

## RTPP
setenv RTPPEXE mpasjedi_rtpp.x
setenv RTPPBuildDir ${commonBuild}/bin

# MPAS-Model
# ----------
setenv MPASCore atmosphere
setenv InitEXE mpas_init_${MPASCore}
setenv InitBuildDir ${commonBuild}/bin
setenv ForecastTopBuildDir ${commonBuild}

# Use a static single-precision build of MPAS-A to conserve resources
setenv ForecastBuildDir /glade/p/mmm/parc/liuz/pandac_common/20220309_mpas_bundle/code/MPAS-gnumpt-single
setenv ForecastEXE ${MPASCore}_model

# TODO: enable single-precision MPAS-A build in mpas-bundle, then use bundle-built executables
# Note to developers: it is easier to use the ForecastBuildDir and ForecastEXE settings below when
# modifying MPAS-Model source code.  The added expense is minimal for short-range cycling tests.
# This also requires modifying the mpiexec executable in forecast.csh.
#setenv ForecastBuildDir ${ForecastTopBuildDir}/bin
#setenv ForecastEXE mpas_${MPASCore}


setenv MPASLookupDir ${ForecastTopBuildDir}/MPAS/core_${MPASCore}
set MPASLookupFileGlobs = (.TBL .DBL DATA COMPATABILITY VERSION)

# Mean state calculator
# ---------------------
setenv meanStateExe      average_netcdf_files_parallel_mpas_gnu-openmpi.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
