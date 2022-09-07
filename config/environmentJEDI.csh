#!/bin/csh -f

if ( $?config_environmentJEDI ) exit 0
setenv config_environmentJEDI 1

source config/auto/build.csh # for compilerUsed

source /etc/profile.d/modules.csh
setenv OPT /glade/work/jedipara/cheyenne/opt/modules
module purge
module use $OPT/modulefiles/core
module load jedi/${compilerUsed}
module load json
module load json-schema-validator
module load atlas/ecmwf-0.29.0 # temp. patch until JEDI stack recovers
limit stacksize unlimited
setenv OOPS_TRACE 0
setenv OOPS_DEBUG 0
#setenv OOPS_TRAPFPE 1
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
setenv F_UFMTENDIAN 'big:101-200'
setenv OMP_NUM_THREADS 1

## CustomPIO
# whether to unload the JEDI module PIO module
# A custom PIO build (outside JEDI modules) must be used consistently across all MPAS-JEDI and
# MPAS-Model executable builds
set CustomPIO = False
if ( CustomPIO == True ) then
  module unload pio
endif

module list
