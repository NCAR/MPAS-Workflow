#!/bin/csh -f

if ( $?config_environmentJEDI ) exit 0

echo "Loading Spack-Stack 1.3.1"
setenv config_environmentJEDI 1

source config/auto/build.csh

if ( "$NCAR_HOST" == "derecho" ) then
	source /etc/profile.d/z00_modules.csh
  module purge
  setenv LMOD_TMOD_FIND_FIRST yes
  if ( "$bundleCompilerUsed" =~  *"intel"* ) then
     module use /lustre/desc1/scratch/epicufsrt/contrib/modulefiles_extra
     module use /lustre/desc1/scratch/epicufsrt/contrib/modulefiles
     module load ecflow/5.8.4
     module load mysql/8.0.33
     module use /glade/work/epicufsrt/contrib/spack-stack/derecho/spack-stack-1.5.0/envs/unified-env/install/modulefiles/Core
     module load stack-intel/2021.10.0
     module load stack-cray-mpich/8.1.25
     module load stack-python/3.10.8
     module load jedi-mpas-env
  else if ( "$bundleCompilerUsed" =~  *"gnu"* ) then
     module load ncarenv/23.09
     module use /glade/work/epicufsrt/contrib/spack-stack/derecho/modulefiles
     module load ecflow/5.8.4
     module load mysql/8.0.33
     module use /glade/work/epicufsrt/contrib/spack-stack/derecho/spack-stack-1.5.1/envs/unified-env/install/modulefiles/Core
     module load stack-gcc/12.2.0
     module load stack-cray-mpich/8.1.25
     module load stack-python/3.10.8
     module load jedi-mpas-env soca-env
     #module load jedi-mpas-env
  endif

  echo setenv LD_LIBRARY_PATH ${mpasBundle}/lib:$LD_LIBRARY_PATH
  setenv LD_LIBRARY_PATH ${mpasBundle}/lib:$LD_LIBRARY_PATH

else if ( "$NCAR_HOST" == "cheyenne" ) then
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
else
  echo "unknown NCAR_HOST:" $NCAR_HOST
endif

limit stacksize unlimited
setenv OOPS_TRACE 0
setenv OOPS_DEBUG 0
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'
setenv OMP_NUM_THREADS 1
setenv FI_CXI_RX_MATCH_MODE 'hybrid'

module list
