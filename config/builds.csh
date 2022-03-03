#!/bin/csh -f

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

set commonBuild = /glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_28FEB2022

# Ungrib
setenv ungribEXE ungrib.exe
setenv WPSBuildDir /glade/work/guerrett/pandac/data/GEFS

# Obs2IODA-v2
setenv obs2iodaEXEC obs2ioda-v2.x
setenv obs2iodaBuildDir /glade/scratch/ivette/NRT-MPAS-JEDI/preprocessing/fork_obs2ioda/obs2ioda/obs2ioda-v2/src
setenv iodaupgradeEXEC ioda-upgrade.x
setenv iodaupgradeBuildDir ${commonBuild}/bin

# Satbias2IODA
setenv satbias2iodaEXE satbias2ioda.x
setenv satbias2iodaBuildDir /glade/scratch/ivette/jedi/ioda-bundle/build/bin

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
setenv ForecastEXE mpas_${MPASCore}
setenv ForecastTopBuildDir ${commonBuild}
setenv ForecastBuildDir ${ForecastTopBuildDir}/bin

setenv MPASLookupDir ${ForecastTopBuildDir}/MPAS/core_${MPASCore}
set MPASLookupFileGlobs = (.TBL .DBL DATA COMPATABILITY VERSION)

# Mean state calculator
# ---------------------
setenv meanStateExe      average_netcdf_files_parallel_mpas_gnu-openmpi.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
