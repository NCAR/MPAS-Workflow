#!/bin/csh -f

if ( $?config_environmentJEDI ) exit 0
setenv config_environmentJEDI 1

source config/auto/build.csh # for bundleCompilerUsed

echo "Loading Spack-Stack 1.3.1"
source /etc/profile.d/modules.csh
module purge
setenv LMOD_TMOD_FIND_FIRST yes
module unuse /glade/u/apps/ch/modulefiles/default/compilers
setenv MODULEPATH_ROOT /glade/work/jedipara/cheyenne/spack-stack/modulefiles
module use /glade/work/jedipara/cheyenne/spack-stack/modulefiles/compilers
module use /glade/work/jedipara/cheyenne/spack-stack/modulefiles/misc
module use /glade/work/epicufsrt/contrib/spack-stack/spack-stack-1.3.1/envs/unified-env/install/modulefiles/Core

if ( "$bundleCompilerUsed" =~  *"gnu"* ) then
  module load stack-gcc/10.1.0
  module load stack-openmpi/4.1.1

else if ( "$bundleCompilerUsed" =~  *"intel"* ) then
  module load stack-intel/19.1.1.217
  module load stack-intel-mpi/2019.7.217
  
endif

module load jedi-mpas-env/unified-dev
limit stacksize unlimited
setenv OOPS_TRACE 0
setenv OOPS_DEBUG 0
#setenv OOPS_TRAPFPE 1
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'
setenv OMP_NUM_THREADS 1

module list
