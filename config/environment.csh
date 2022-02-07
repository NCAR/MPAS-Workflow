#!/bin/csh -f

source config/builds.csh

#######################
# build/run environment
#######################

source config/environmentForJedi.csh ${BuildCompiler}

## CustomPIO
# whether to unload the JEDI module PIO module
# A custom PIO build (outside JEDI modules) must be used consistently across all MPAS-JEDI and
# MPAS-Model executable builds
set CustomPIO = False
if ( CustomPIO == True ) then
  module unload pio
endif

module load nco
setenv OOPS_DEBUG 0
#setenv OOPS_TRAPFPE 1
setenv F_UFMTENDIAN 'big:101-200'
setenv OMP_NUM_THREADS 1

module load python
source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh default

module load nccmp

module list
