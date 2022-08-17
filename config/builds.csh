#!/bin/csh -f

if ( $?config_builds ) exit 0
set config_builds = 1

source config/model.csh
source config/scenario.csh builds

#############################
## build directory structures
#############################

# mpas-bundle applications
# ========================
# + at this time, all mpas-bundle executables should be built in the same environment, one that is
#   consistent with config/environmentJEDI.csh
# + it is preferred to build mpas-bundle with a single-precision MPAS-Model, such that
#   set(MPAS_DOUBLE_PRECISION "OFF") is used in mpas-bundle/CMakeLists.txt

# default mpas-bundle build directory
$setLocal commonBuild

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
setenv InitEXE mpas_init_${MPASCore}
setenv InitBuildDir ${commonBuild}/bin
setenv ForecastTopBuildDir /glade/work/guerrett/pandac/build/mpas-bundle_gnu-openmpi_10AUG2022_single

# use forecast executable built in the bundle
setenv ForecastBuildDir ${ForecastTopBuildDir}/bin
setenv ForecastEXE mpas_${MPASCore}

setenv MPASLookupDir ${ForecastTopBuildDir}/MPAS/core_${MPASCore}
set MPASLookupFileGlobs = (.TBL .DBL DATA COMPATABILITY VERSION)

# Alternatively, use a stand-alone single-precision build of MPAS-A with GNU-MPT
#setenv ForecastBuildDir /glade/p/mmm/parc/liuz/pandac_common/20220309_mpas_bundle/code/MPAS-gnumpt-single
#setenv ForecastEXE ${MPASCore}_model

# Note: this also requires modifying forecast.csh:
#@@ -28,7 +28,7 @@ source config/tools.csh
# source config/model.csh
# source config/modeldata.csh
# source config/builds.csh
#-source config/environmentJEDI.csh
#+source config/environmentMPT.csh
# source config/applications/forecast.csh
# set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
# set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
#@@ -203,8 +203,8 @@ else
#   rm ./${ForecastEXE}
#   ln -sfv ${ForecastBuildDir}/${ForecastEXE} ./
#   # mpiexec is for Open MPI, mpiexec_mpt is for MPT
#-  mpiexec ./${ForecastEXE}
#-  #mpiexec_mpt ./${ForecastEXE}
#+  #mpiexec ./${ForecastEXE}
#+  mpiexec_mpt ./${ForecastEXE}


# Non-bundle applications
# =======================

# Ungrib
# ------
setenv ungribEXE ungrib.exe
setenv WPSBuildDir /glade/work/guerrett/pandac/data/GEFS

# Obs2IODA-v2
# -----------
setenv obs2iodaEXEC obs2ioda-v2.x
setenv obs2iodaBuildDir /glade/p/mmm/parc/ivette/pandac/fork_obs2ioda/obs2ioda/obs2ioda-v2/src
setenv iodaupgradeEXEC ioda-upgrade.x
setenv iodaupgradeBuildDir ${commonBuild}/bin

# Mean state calculator
# ---------------------
setenv meanStateExe      average_netcdf_files_parallel_mpas_gnu-openmpi.x
setenv meanStateBuildDir /glade/work/guerrett/pandac/work/meanState
