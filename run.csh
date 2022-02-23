#!/bin/csh -f

source config/environmentPython.csh

####################################################################################################
# This script runs an pre-configured set of cylc suites via MPAS-Workflow. If the user has
# previously executed this script with the same config, and one or more of the scenarios is
# already running, then executing this script again will cause drive.csh to kill those running
# suites.
####################################################################################################

## Usage:
#   source env/cheyenne.${YourShell}
#   ./autorun.csh

## stage
# Choose which stage of the workflow to run for all scenarios.  It can be useful to run only the
# SetupWorkflow stage in order to check that all scripts run correctly or to re-initialize
# the MPAS-Worlfow config directories of all of the scenarios.  The latter is useful when a simple
# update to the config directory will enable a workflow task to run, and avoids re-starting
# the one or more cylc suites.  drive.csh automatically stops active scenario suites when the user
# executes this script script.
# OPTIONS: drive, SetupWorkflow
set stage = drive

## config
# A YAML file describing the set of scenarios to run
#Options:
# + PullRequest
# + OneMonth120km3dvar
# + OneMonth120km3denvar
# + OneMonth30km-60km3denvar
set config = PullRequest

###################################################################################################
# get the configuration (only developers should modify this)
###################################################################################################

# config tools
source config/config.csh

# defaults config
set defaults = run/config/defaults.yaml

# this config
set runConfig = run/config/${config}.yaml

# getRun and setRun are helper functions that pick out individual
# configuration elements from within the "run" key of the run configuration
set getRun = "$getConfig $defaults $runConfig run"
setenv setRun "source $setConfig $defaults $runConfig run"

## getRestore and setRestore are helper functions that pick out individual
## configuration elements from within the "run" key of the run configuration
#set getRestore = "$getConfig $defaults $runConfig restore"
setenv setRestore "source $setConfig $defaults $runConfig restore"


# these values will be used during the run phase
# see run/config/defaults.yaml for configuration documentation
set scenarios = (`$getRun scenarios`)
$setRun ExpSuffix
$setRun CPQueueName
$setRun initialCyclePoint
$setRun finalCyclePoint

###################################################################################################
# run the scenarios (only developers should modify this)
###################################################################################################

sed -i 's@^set\ ExpSuffix\ =\ .*@set\ ExpSuffix\ =\ "'$ExpSuffix'"@' config/experiment.csh
sed -i 's@^setenv\ CPQueueName.*@setenv\ CPQueueName\ '$CPQueueName'@' config/job.csh
sed -i 's@^set\ initialCyclePoint\ =\ .*@set\ initialCyclePoint\ =\ '$initialCyclePoint'@' drive.csh
sed -i 's@^set\ finalCyclePoint\ =\ .*@set\ finalCyclePoint\ =\ '$finalCyclePoint'@' drive.csh

foreach scenario ($scenarios)
  echo ""
  echo ""
  echo "##################################################################"
  echo "${0}: Running scenario: $scenario"

  sed -i 's@^set\ scenario\ =\ .*@set\ scenario\ =\ '$scenario'@' config/experiment.csh
  sed -i 's@^set\ SuiteName\ =\ .*@set\ SuiteName\ =\ '$scenario'@' drive.csh
  ./${stage}.csh

  if ( $status != 0 ) then
    echo "ERROR in $0 : error when setting up $scenario" > ./FAIL
    exit 1
  endif
end

###################################################################################################
# restore settings (only developers should modify this)
###################################################################################################

## restore* settings
# these values are restored now that all suites are initialized
$setRestore scenario
$setRestore ExpSuffix
$setRestore CPQueueName
$setRestore initialCyclePoint
$setRestore finalCyclePoint

sed -i 's@^set\ scenario\ =\ .*@set\ scenario\ =\ '$scenario'@' config/experiment.csh
sed -i 's@^set\ SuiteName\ =\ .*@set\ SuiteName\ =\ ${ExperimentName}@' drive.csh

sed -i 's@^set\ ExpSuffix\ =\ .*@set\ ExpSuffix\ =\ "'$ExpSuffix'"@' config/experiment.csh

sed -i 's@^setenv\ CPQueueName.*@setenv\ CPQueueName\ '$CPQueueName'@' config/job.csh

sed -i 's@^set\ initialCyclePoint\ =\ .*@set\ initialCyclePoint\ =\ '$initialCyclePoint'@' drive.csh
sed -i 's@^set\ finalCyclePoint\ =\ .*@set\ finalCyclePoint\ =\ '$finalCyclePoint'@' drive.csh
