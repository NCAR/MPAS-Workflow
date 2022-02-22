#!/bin/csh -f

# Process arguments
# =================
## args
# thisValidDate: date, cycle date
set thisValidDate = "$1"


# Setup environment
# =================
source config/experiment.csh
source config/filestructure.csh

## VARBC
setenv INITIAL_VARBC_TABLE ${FixedInput}/satbias/satbias_crtm_in

## Satbias coefficients
setenv SatbiasFixcoeff /glade/p/mmm/parc/ivette/SATBIAS_fix

if ( $Satbias == Fix ) then
  # Fixed satbias
  # ===========
  set yyyy = `echo ${thisValidDate} | cut -c 1-4`
  set SatbiasDir = ${SatbiasFixcoeff}/${yyyy}
else
  # Online satbias
  # ===========
  set SatbiascoeffDir = ${ObsWorkDir}/${thisValidDate}/Satbias
  set SatbiasDir = ${SatbiascoeffDir}
endif

exit 0
