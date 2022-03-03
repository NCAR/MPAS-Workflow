#!/bin/csh -f

# Setup environment
# =================
source config/workflow.csh
source config/variational.csh
#TODO: the satbias method is application-dependent (should always be off for hofx), which means the
#   yaml-prep belongs in PrepVariational, not PrepJEDI
# Possibly, all of the below settings could be moved to config/variational.csh
# For example, could create a sub-yaml under variational within scenarios/base/variational.yaml:
#variational:
#  satbias:
#    type: options like None, GDASDynamic, GDASFixed, VarBC (later)
#    satelliteBiasFixedcoeff: /glade/p/mmm/parc/ivette/SATBIAS_fixed
#    INITIAL_VARBC_TABLE: /glade/work/guerrett/pandac/fixed_input/satbias/satbias_crtm_in

#note: a major change from the *.csh config files is to use absolute directories for all static
# data in the yaml to avoid confusion and to make later modifications easier to follow

## VARBC
setenv INITIAL_VARBC_TABLE /glade/work/guerrett/pandac/fixed_input/satbias/satbias_crtm_in

## satelliteBias fixed coefficients for first date of specific time periods
setenv satelliteBiasFixedcoeff /glade/p/mmm/parc/ivette/SATBIAS_fixed

if ( $satelliteBias == GDASDynamic ) then
  # Dynamic satbias using GDAS coefficientes
  # ===========
  set satelliteBiasDir = ${satelliteBiasDir}
else
  # GDAS fixed satbias for single cycle
  # ===========
  set yyyy = `echo ${FirstCycleDate} | cut -c 1-4`
  set satelliteBiasDir = ${satelliteBiasFixedcoeff}/${yyyy}
#TODO: use the following
#else if ( $satelliteBias == GDASFixed ) then
#  # GDAS fixed satbias for single cycle
#  # ===========
#  set yyyy = `echo ${FirstCycleDate} | cut -c 1-4`
#  set satelliteBiasDir = ${satelliteBiasFixedcoeff}/${yyyy}
#else
#  set satelliteBiasDir = None
endif

exit 0
