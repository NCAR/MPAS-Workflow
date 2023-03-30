#!/bin/csh -f

if ( $?config_environmentJEDI ) exit 0
setenv config_environmentJEDI 1

source config/auto/build.csh # for compilerUsed

source /etc/profile.d/modules.csh
module purge
module unuse /glade/u/apps/ch/modulefiles/default/compilers
setenv MODULEPATH_ROOT /glade/work/jedipara/cheyenne/spack-stack/modulefiles
module use /glade/work/jedipara/cheyenne/spack-stack/modulefiles/compilers
module use /glade/work/jedipara/cheyenne/spack-stack/modulefiles/misc


if ( "$compilerUsed" =~  *"gnu"* ) then
  module use /glade/work/jedipara/cheyenne/spack-stack/spack-stack-v1/envs/skylab-3.0.0-gnu-10.1.0/install/modulefiles/Core
  module load stack-gcc/10.1.0
  module load stack-openmpi/4.1.1
  module load jedi-mpas-env/1.0.0

else if ( "$compilerUsed" =~  *"intel"* ) then
  module use /glade/work/jedipara/cheyenne/spack-stack/spack-stack-v1/envs/skylab-3.0.0-intel-19.1.1.217/install/modulefiles/Core
  module load stack-intel/19.1.1.217
  module load stack-intel-mpi/2019.7.217
  module load jedi-mpas-env/1.0.0

endif

limit stacksize unlimited
setenv OOPS_TRACE 0
setenv OOPS_DEBUG 0
#setenv OOPS_TRAPFPE 1
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'
setenv OMP_NUM_THREADS 1

module list
