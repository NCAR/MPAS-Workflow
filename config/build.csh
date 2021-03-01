#!/bin/csh -f

############################
# code build/run environment
############################
source /etc/profile.d/modules.csh
setenv OPT /glade/work/miesch/modules
module use $OPT/modulefiles/core

setenv BuildCompiler "gnu-openmpi"
#setenv BuildCompiler "intel-impi"
set mainModule = ${BuildCompiler}

module purge
module load jedi/${mainModule}

setenv CUSTOMPIO         ""
if ( CUSTOMPIO != "" ) then
  module unload pio
endif

module load nco
limit stacksize unlimited
setenv OOPS_TRACE 0
setenv OOPS_DEBUG 0
#setenv OOPS_TRAPFPE 1
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'
setenv OMP_NUM_THREADS 1

module load python/3.7.5


#############################
## build directory structures
#############################

# MPAS-JEDI
# ---------
## Variational
if ( "$DAType" =~ *"eda"* ) then
  setenv VariationalEXE mpasjedi_eda.x
else
  setenv VariationalEXE mpasjedi_variational.x
endif
setenv VariationalBuildDir /glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_19FEB2021/bin

## HofX
setenv HofXEXE mpasjedi_hofx_nomodel.x
setenv HofXBuildDir /glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_19FEB2021/bin

## RTPP
setenv RTPPEXE mpasjedi_rtpp.x
setenv RTPPBuildDir /glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_feature--rtpp_app/bin

# MPAS-Model
# ----------
setenv MPASCore atmosphere
setenv ForecastEXE mpas_${MPASCore}
setenv ForecastTopBuildDir /glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_19FEB2021

setenv ForecastBuildDir ${ForecastTopBuildDir}/bin

set ForecastProject = MPAS
setenv ForecastLookupDir ${ForecastTopBuildDir}/${ForecastProject}/core_${MPASCore}
set ForecastLookupFileGlobs = (.TBL .DBL DATA COMPATABILITY VERSION)

# Mean state calculator
# ---------------------
setenv meanStateExe      average_netcdf_files_parallel_mpas_${BuildCompiler}.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
