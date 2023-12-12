#!/bin/csh -f

if ( $?config_environmentForecast ) exit 0
setenv config_environmentForecast 1

source config/auto/build.csh # for forecastDirectory

if ("$forecastDirectory" == "bundle") then
  source config/environmentJEDI.csh
  setenv mpiCommand mpiexec
else
    if ( "$NCAR_HOST" == "cheyenne" ) then
      source /etc/profile.d/modules.csh
      module purge

      #gnu
      #module load gnu/9.1.0
      #setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'

      #intel
      module load intel/19.0.5

      module load mpt/2.22
      module load netcdf-mpi/4.7.3
      module load pnetcdf/1.12.1
      module load pio/2.4.4
      module load ncarenv/1.3
      module load ncarcompilers/0.5.0
      module load nco
      setenv mpiCommand mpiexec_mpt
    else if ("$NCAR_HOST" == "derecho") then
      source /etc/profile.d/z00_modules.csh
      module purge

      module load intel-oneapi/2023.0.0
      module load cray-mpich/8.1.25
      module load parallel-netcdf/1.12.3
      module load parallelio/2.5.10
      module load ncl/6.6.2
      module load hdf5/1.12.2
      module load netcdf/4.9.2
      module load ncarcompilers/1.0.0
      module load nco/5.1.4
      setenv mpiCommand mpiexec
    else
      echo "unknown NCAR_HOST: $NCAR_HOST"
    endif
    setenv F_UFMTENDIAN 'big:101-200'
    setenv FI_CXI_RX_MATCH_MODE 'hybrid'
    limit stacksize unlimited

    module list

endif
