#!/bin/csh -f

#############################
## build directory structures
#############################

## BuildCompiler
# {compiler}-{mpi-implementation} combination that selects the JEDI module to be loaded in
# config/environment.csh
# OPTIONS: gnu-openmpi, intel-impi
setenv BuildCompiler 'gnu-openmpi'

# Note: at this time, all executables should be built in the same environment, one that is
# consistent with config/environment.csh

# Ungrib
setenv ungribEXE ungrib.exe
setenv WPSBuildDir /glade/work/guerrett/pandac/data/GEFS

set commonBuild = /glade/scratch/syha/mpas-bundle-iaufix-build
#set commonBuild = /glade/work/syha/mpas-bundle-build-gnu-openmpi #default

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
