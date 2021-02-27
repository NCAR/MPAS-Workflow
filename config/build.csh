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
set BuildUser = guerrett
set TopBuildDir = /glade/work/${BuildUser}/pandac

# MPAS-JEDI
# ---------
set BundleFeatureName = ''
set BundleFeatureName = '_19FEB2021'

if ( "$DAType" =~ *"eda"* ) then
  setenv VariationalEXE mpasjedi_eda.x
else
  setenv VariationalEXE mpasjedi_variational.x
endif
set VariationalBuild = mpas-bundle${CUSTOMPIO}_${BuildCompiler}${BundleFeatureName}
setenv VariationalBuildDir ${TopBuildDir}/build/${VariationalBuild}/bin

setenv HofXEXE mpasjedi_hofx_nomodel.x
set HofXBuild = mpas-bundle${CUSTOMPIO}_${BuildCompiler}${BundleFeatureName}
setenv HofXBuildDir ${TopBuildDir}/build/${HofXBuild}/bin

setenv RTPPEXE mpasjedi_rtpp.x
set RTPPBuild = mpas-bundle${CUSTOMPIO}_${BuildCompiler}_feature--rtpp_app
setenv RTPPBuildDir ${TopBuildDir}/build/${RTPPBuild}/bin

# MPAS-Model
# ----------
setenv MPASCore atmosphere
setenv ForecastEXE mpas_${MPASCore}
set ForecastProject = MPAS
set ForecastBuild = mpas-bundle${CUSTOMPIO}_${BuildCompiler}${BundleFeatureName}
setenv ForecastBuildDir ${TopBuildDir}/build/${ForecastBuild}/bin
setenv ForecastLookupDir ${TopBuildDir}/build/${ForecastBuild}/${ForecastProject}/core_${MPASCore}
set ForecastLookupFileGlobs = (.TBL .DBL DATA COMPATABILITY VERSION)

# Mean state calculator
# ---------------------
setenv meanStateExe      average_netcdf_files_parallel_mpas_${BuildCompiler}.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
