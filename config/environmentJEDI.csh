#!/bin/csh -f

setenv config_environmentJEDI 1
source /etc/profile.d/z00_modules.csh
source config/auto/build.csh

echo "Loading Spack-Stack 1.3.1"

module purge
setenv LMOD_TMOD_FIND_FIRST yes
module use /lustre/desc1/scratch/epicufsrt/contrib/modulefiles_extra
module use /lustre/desc1/scratch/epicufsrt/contrib/modulefiles
module load ecflow/5.8.4
module load mysql/8.0.33
module use /glade/work/epicufsrt/contrib/spack-stack/derecho/spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core
module load stack-intel/2021.10.0
module load stack-cray-mpich/8.1.25
module load stack-python/3.10.8
module load jedi-mpas-env

limit stacksize unlimited
setenv OOPS_TRACE 0
setenv OOPS_DEBUG 0
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'
setenv OMP_NUM_THREADS 1
setenv FI_CXI_RX_MATCH_MODE 'hybrid'

module list

setenv LD_LIBRARY_PATH ${mpasBundle}/lib:$LD_LIBRARY_PATH
