#!/bin/csh -f

if ( $?config_environmentForJedi ) exit 0
setenv config_environmentForJedi 1

# Process arguments
# =================
## args
# BuildCompiler: combination of compiler and MPI implementation used to build JEDI
#                (defined in config/builds.csh)
# OPTIONS: gnu-openmpi, intel-impi

set BuildCompiler = "$1"

source /etc/profile.d/modules.csh
setenv OPT /glade/work/jedipara/cheyenne/opt/modules
module purge
module use $OPT/modulefiles/core
module load jedi/$BuildCompiler
module load json
module load json-schema-validator
unalias ecbuild
#setenv LOCAL_PATH_JEDI_TESTFILES /glade/u/home/maryamao/JEDI_test_files
git lfs install
limit stacksize unlimited
setenv OOPS_TRACE 0  # Note: Some ctests fail when OOPS_TRACE=1
module list
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
