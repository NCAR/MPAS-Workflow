#!/bin/csh -f

# Setup environment
# =================
source config/experiment.csh

## VARBC
setenv INITIAL_VARBC_TABLE ${FixedInput}/satbias/satbias_crtm_in

## Satbias fixed coefficients for first date of specific time periods
setenv SatbiasFixedcoeff /glade/p/mmm/parc/ivette/SATBIAS_fixed

if ( $Satbias == GDASDynamic ) then
  # Dynamic satbias using GDAS coefficientes
  # ===========
  set SatbiasDir = ${SatbiasDir}
else
  # GDAS fixed satbias for single cycle
  # ===========
  set yyyy = `echo ${FirstCycleDate} | cut -c 1-4`
  set SatbiasDir = ${SatbiasFixedcoeff}/${yyyy}
endif

exit 0
