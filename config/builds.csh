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

# MPAS-JEDI
# ---------
## Variational
if ( "$DAType" =~ *"eda"* ) then
  setenv VariationalEXE mpasjedi_eda.x
else
  setenv VariationalEXE mpasjedi_variational.x
endif
setenv VariationalBuildDir /glade/scratch/vahl/mpasbundletest/build/bin

## HofX
setenv HofXEXE mpasjedi_hofx_nomodel.x
setenv HofXBuildDir /glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_19FEB2021/bin

## RTPP
setenv RTPPEXE mpasjedi_rtpp.x
setenv RTPPBuildDir /glade/scratch/vahl/mpasbundletest/build/bin

# MPAS-Model
# ----------
setenv MPASCore atmosphere
setenv ForecastEXE mpas_${MPASCore}
setenv ForecastTopBuildDir /glade/scratch/vahl/mpasbundletest/build/bin
setenv ForecastBuildDir ${ForecastTopBuildDir}/bin

setenv MPASLookupDir ${ForecastTopBuildDir}/MPAS/core_${MPASCore}
set MPASLookupFileGlobs = (.TBL .DBL DATA COMPATABILITY VERSION)

# Mean state calculator
# ---------------------
setenv meanStateExe      average_netcdf_files_parallel_mpas_gnu-openmpi.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
