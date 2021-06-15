#!/bin/csh -f

source config/experiment.csh

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

set commonBuild = /glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_bugfix--out-nchans

# MPAS-JEDI
# ---------
## Variational
if ( "$DAType" =~ *"eda"* ) then
  setenv VariationalEXE mpasjedi_eda.x
else
  setenv VariationalEXE mpasjedi_variational.x
endif
setenv VariationalBuildDir ${commonBuild}/bin

## HofX
setenv HofXEXE mpasjedi_hofx3d.x
setenv HofXBuildDir ${commonBuild}/bin

## RTPP
setenv RTPPEXE mpasjedi_rtpp.x
setenv RTPPBuildDir ${commonBuild}/bin

# MPAS-Model
# ----------
setenv MPASCore atmosphere
setenv ForecastEXE mpas_${MPASCore}
setenv ForecastTopBuildDir ${commonBuild}
setenv ForecastBuildDir ${ForecastTopBuildDir}/bin

setenv MPASLookupDir ${ForecastTopBuildDir}/MPAS/core_${MPASCore}
set MPASLookupFileGlobs = (.TBL .DBL DATA COMPATABILITY VERSION)

# Mean state calculator
# ---------------------
setenv meanStateExe      average_netcdf_files_parallel_mpas_gnu-openmpi.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
