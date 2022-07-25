#!/bin/csh -f

if ( $?config_observations ) exit 0
setenv config_observations 1

source config/scenario.csh observations

# getObservationsOrNone exposes the observations section of the config for run-time-dependent
# behaviors
setenv getObservationsOrNone "${getLocalOrNone}"

# nested observations__resource
$setNestedObservations resource

# mini-workflow that prepares observations for IODA ingest
$setLocal ${observations__resource}.PrepareObservationsTasks
set tmp = ""
foreach task ($PrepareObservationsTasks)
  set tmp = "$tmp"'"'$task'"'", "
end
set PrepareObservationsTasks = "$tmp"

$setLocal convertToIODAObservations
$setLocal GDASObsErrtable
$setLocal CRTMTABLES
$setLocal InterpolationType

# static directories for bias correction files
set fixedCoeff = /glade/p/mmm/parc/ivette/pandac/SATBIAS_fixed
set fixedTlapmeanCov = /glade/p/mmm/parc/ivette/pandac/SATBIAS_fixed/2018
set initialVARBCcoeff = /glade/p/mmm/parc/ivette/pandac/SATBIAS_fixed/2018

$setLocal job.get__retry
$setLocal job.convert__retry


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/variables/auto/observations.rc ) then
cat >! include/variables/auto/observations.rc << EOF
{% set PrepareObservationsTasks = [${PrepareObservationsTasks}] %}
{% set PrepareObservations = " => ".join(PrepareObservationsTasks) %}
EOF

endif

if ( ! -e include/tasks/auto/observations.rc ) then
cat >! include/tasks/auto/observations.rc << EOF
  [[GetObs]]
    inherit = BATCH
    script = \$origin/applications/GetObs.csh
    [[[job]]]
      execution time limit = PT10M
      execution retry delays = ${get__retry}
  [[ObsToIODA]]
    inherit = BATCH
    script = \$origin/applications/ObsToIODA.csh
    [[[job]]]
      execution time limit = PT10M
      execution retry delays = ${convert__retry}
    # currently ObsToIODA has to be on Cheyenne, because ioda-upgrade.x is built there
    # TODO: build ioda-upgrade.x on casper, remove CP directives below
    # Note: memory for ObsToIODA may need to be increased when hyperspectral and/or
    #       geostationary instruments are added
    [[[directives]]]
      -m = ae
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select=1:ncpus=1:mem=10GB
  [[ObsReady]]
    inherit = BACKGROUND
EOF

endif
