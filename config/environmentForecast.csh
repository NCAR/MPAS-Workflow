#!/bin/csh -f

if ( $?config_environmentForecast ) exit 0
setenv config_environmentForecast 1

source config/auto/build.csh # for forecastDirectory

if ("$forecastDirectory" == "bundle") then
  source config/environmentJEDI.csh
  setenv mpiCommand mpiexec
else
  source /etc/profile.d/modules.csh
  module purge

  #gnu
  #module load gnu/9.1.0
  #setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'

  #intel
  module load intel/19.0.5
  setenv F_UFMTENDIAN 'big:101-200'

  module load mpt/2.22
  module load netcdf-mpi/4.7.3
  module load pnetcdf/1.12.1
  module load pio/2.4.4
  module load ncarenv/1.3
  module load ncarcompilers/0.5.0
  module load nco
  limit stacksize unlimited

  module list

  setenv mpiCommand mpiexec_mpt

endif
