#!/bin/csh -f

source config/builds.csh

#######################
# build/run environment
#######################

source /etc/profile.d/modules.csh
setenv OPT /glade/work/jedipara/cheyenne/opt/modules
module purge
module use $OPT/modulefiles/core
module load jedi/${BuildCompiler}

## CustomPIO
# whether to unload the JEDI module PIO module
# A custom PIO build (outside JEDI modules) must be used consistently across all MPAS-JEDI and
# MPAS-Model executable builds
set CustomPIO = False
if ( CustomPIO == True ) then
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

module load nccmp

module list
