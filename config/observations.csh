#!/bin/csh -f

if ( $?config_observations ) exit 0
setenv config_observations 1

source config/scenario.csh observations

# getObservationsOrNone exposes the observations section of the config for run-time-dependent
# behaviors
setenv getObservationsOrNone "${getLocalOrNone}"

# nested observations__resource
$setNestedObservations resource

$setLocal convertToIODAObservations
$setLocal GDASObsErrtable
$setLocal CRTMTABLES
$setLocal InterpolationType
#$setLocal initialVARBCcoeff
#$setLocal fixedTlapmeanCov

# static directories for bias correction files
#set fixedCoeff = /glade/p/mmm/parc/ivette/pandac/SATBIAS_fixed

# liuz test
setenv fixedCoeff        /glade/p/mmm/parc/liuz/pandac_hybrid/fix_input/satbias
setenv fixedTlapmeanCov  /glade/p/mmm/parc/liuz/pandac_hybrid/fix_input/satbias/2018
setenv initialVARBCcoeff /glade/p/mmm/parc/liuz/pandac_hybrid/fix_input/satbias/2018
