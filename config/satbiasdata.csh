#!/bin/csh -f

# Setup environment
# =================
source config/workflow.csh
source config/variational.csh
#TODO: the satbias method is application-dependent (always be off for hofx for now), which means the
#  yaml-prep belongs in PrepVariational, not PrepJEDI.  If we decide to include bias correction in
#  hofx later, we can re-purpose the modularized solution for variational.
# Possibly, all of the settings in satbiasdata.csh could be moved to config/variational.csh
# For example, could create a sub-yaml under variational within scenarios/base/variational.yaml:
#variational:
#  satbias:
#    type: options like None, GDASDynamic, GDASFixed, VarBC (later)
#    fixedCoeff: /glade/p/mmm/parc/ivette/pandac/SATBIAS_fixed
#    initialVarBCCoeff: /glade/work/guerrett/pandac/fixed_input/satbias/satbias_crtm_in

# then in variational.csh:
#setenv setNestedVariational "source $setNestedConfig $baseConfig $scenarioConfig variational"
#$setNestedVariational satbias.type
#$setNestedVariational satbias.fixedCoeff
#$setNestedVariational satbias.initialVarBCCoeff


#Later when variational.satbias.type is needed:
#if ( $variational__satbias__type == GDASDynamic ) then

#variational.satbias.fixedCoeff can be accessed using $variational__satbias__fixedCoeff

#similarly, use $variational__satbias__initialVarBCCoeff

#notes:
# + a major change from the *.csh config files is to use absolute directories for all static
#   data in the yaml to avoid confusion and to make later modifications easier to follow
# + TABLE is replaced with Coeff above
# + ALL_CAPS_NAMES are replaced with camelCaseNames

## VARBC
setenv INITIAL_VARBC_TABLE /glade/work/guerrett/pandac/fixed_input/satbias/satbias_crtm_in

## satelliteBias fixed coefficients for first date of specific time periods
setenv satelliteBiasFixedcoeff /glade/p/mmm/parc/ivette/pandac/SATBIAS_fixed

if ( $satelliteBias == GDASDynamic ) then
  # Dynamic satbias using GDAS coefficientes
  # ===========
  set satelliteBiasDir = ${satelliteBiasDir}
else
  # GDAS fixed satbias for single cycle
  # ===========
  set yyyy = `echo ${FirstCycleDate} | cut -c 1-4`
  set satelliteBiasDir = ${satelliteBiasFixedcoeff}/${yyyy}
#TODO: use something like the following
#else if ( $satelliteBias == GDASFixed ) then
#  # GDAS fixed satbias for single cycle
#  # ===========
#  set yyyy = `echo ${FirstCycleDate} | cut -c 1-4`
#  set satelliteBiasDir = ${satelliteBiasFixedcoeff}/${yyyy}
#else if ( $satelliteBias == None ) then
#  set satelliteBiasDir = None
#else
#  throw an error
endif

exit 0
