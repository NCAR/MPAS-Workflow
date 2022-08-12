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

# static directories for bias correction files
set fixedCoeff = /glade/work/jban/pandac/fix_input/satbias
set fixedTlapmeanCov = /glade/work/jban/pandac/fix_input/satbias/2018
set initialVARBCcoeff = /glade/work/jban/pandac/fix_input/satbias/2018
