#!/bin/csh -f

setenv config_environmentForecast 1
source /etc/profile.d/z00_modules.csh
source config/auto/build.csh # for forecastDirectory
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
setenv F_UFMTENDIAN 'big:101-200'
limit stacksize unlimited
setenv mpiCommand mpiexec
