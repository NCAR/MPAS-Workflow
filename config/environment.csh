#!/bin/csh -f

if ( $?config_environment ) exit 0
setenv config_environment 1

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

source config/environmentPython.csh

module load nccmp

module list
